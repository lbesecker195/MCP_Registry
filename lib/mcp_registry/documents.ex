defmodule McpRegistry.Documents do
  @moduledoc """
  Fetches the machine-readable files a listing points at -- its site's
  `llms.txt` and its repository's `AGENTS.md` -- so their changes can go in the
  listing's changelog.

  ## Polling, not webhooks

  GitHub webhooks need admin rights on the repository, or a GitHub App the
  owner installs. Neither exists for the tens of thousands of repositories in
  this catalogue, and llms.txt lives on websites that have no webhooks at all.
  So this polls: each URL once a week, with `If-None-Match` and
  `If-Modified-Since`, so an unchanged file costs a `304` and no body.
  raw.githubusercontent.com honours both.

  ## Fetching URLs that publishers choose

  `website_url` is whatever a publisher typed, so this treats every URL as
  hostile until checked:

    * **https only**, on the default port.
    * **The host must resolve to a public address.** A listing pointing at
      `169.254.169.254` would otherwise have this server read cloud metadata
      on its behalf. Redirects are followed by hand so every hop is checked,
      not only the first.
    * **Bodies stream with a hard cap** of #{div(262_144, 1024)} KB. A file is never
      downloaded first and truncated after.
    * **HTML is treated as absent.** Many sites answer any path with their
      single-page-app shell and a `200`, which would otherwise make every
      such site appear to publish an llms.txt.

  ## What gets recorded

  A document's first fetch is a baseline. After that a changed body records
  the lines added and removed; a file that appears where one was confirmed
  absent, or disappears where one was present, records that too. A failed
  fetch -- a timeout, a 5xx, a 403 from a bot filter -- records nothing and
  keeps what was known, because an outage is not a removal.
  """
  import Ecto.Query

  alias McpRegistry.Changes
  alias McpRegistry.Documents.Document
  alias McpRegistry.Registry.{Logo, Server}
  alias McpRegistry.Repo

  @max_bytes 262_144
  @max_redirects 3
  # Per change: how many changed lines are kept, and how much of each.
  @diff_lines 200
  @line_chars 500

  @default_batch 100
  @default_concurrency 4
  @default_recheck_days 7

  # --- Which documents a listing points at ----------------------------------

  @doc """
  The documents a listing points at, as `[{kind, url}]`.

  llms.txt is looked for at the root of the listing's website, or failing
  that the domain its namespace was verified for -- `com.cloudflare` means
  cloudflare.com. AGENTS.md is looked for at the root of a GitHub repository.
  """
  def urls_for(%{} = server) do
    [llms_txt_url(server), agents_md_url(server)] |> Enum.reject(&is_nil/1)
  end

  defp llms_txt_url(server) do
    case website_origin(server.website_url) || namespace_origin(server.name) do
      nil -> nil
      origin -> {"llms_txt", origin <> "/llms.txt"}
    end
  end

  defp agents_md_url(%{repository_url: url}) when is_binary(url) do
    with %URI{host: host, path: "/" <> path} when host in ["github.com", "www.github.com"] <-
           URI.parse(url),
         [_owner, repo | _] <- String.split(path, "/", trim: true),
         owner when is_binary(owner) <- Logo.repository_login(url),
         repo = String.replace_suffix(repo, ".git", ""),
         true <- Regex.match?(~r/\A[A-Za-z0-9._-]{1,100}\z/, repo) do
      {"agents_md", "https://raw.githubusercontent.com/#{owner}/#{repo}/HEAD/AGENTS.md"}
    else
      _ -> nil
    end
  end

  defp agents_md_url(_), do: nil

  defp website_origin(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host, port: port}
      when scheme in ["http", "https"] and is_binary(host) and host != "" and
             port in [nil, 80, 443] ->
        if domain?(host), do: "https://" <> String.downcase(host)

      _ ->
        nil
    end
  end

  defp website_origin(_), do: nil

  # A reverse-DNS namespace names a domain the official registry verified.
  # io.github.* names a GitHub account instead, which has no llms.txt.
  defp namespace_origin("io.github." <> _), do: nil

  defp namespace_origin(name) when is_binary(name) do
    host =
      name
      |> String.split("/", parts: 2)
      |> List.first()
      |> String.split(".")
      |> Enum.reverse()
      |> Enum.join(".")

    if domain?(host), do: "https://" <> String.downcase(host)
  end

  defp namespace_origin(_), do: nil

  defp domain?(host) do
    labels = String.split(host, ".")

    length(labels) >= 2 and
      Enum.all?(labels, &Regex.match?(~r/\A[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\z/i, &1)) and
      Regex.match?(~r/\A[a-z]{2,}\z/i, List.last(labels))
  end

  # --- Discovery -------------------------------------------------------------

  @doc """
  Rebuilds which listing points at which document, and adds any new URLs as
  pending. Documents no listing points at any more are dropped; their
  recorded changes stay, since history does not stop being true.
  """
  def discover do
    servers =
      Server
      |> where([s], s.status == "active")
      |> select([s], struct(s, [:id, :name, :website_url, :repository_url]))
      |> Repo.all()

    links =
      for s <- servers, {kind, url} <- urls_for(s), do: %{server_id: s.id, kind: kind, url: url}

    now = DateTime.utc_now()

    {:ok, _} =
      Repo.transaction(
        fn ->
          Repo.delete_all("server_documents")
          links |> Enum.chunk_every(5_000) |> Enum.each(&Repo.insert_all("server_documents", &1))

          links
          |> Enum.uniq_by(& &1.url)
          |> Enum.map(&%{url: &1.url, kind: &1.kind, inserted_at: now, updated_at: now})
          |> Enum.chunk_every(5_000)
          |> Enum.each(
            &Repo.insert_all(Document, &1, on_conflict: :nothing, conflict_target: :url)
          )

          Repo.query!("DELETE FROM documents d WHERE NOT EXISTS
                         (SELECT 1 FROM server_documents sd WHERE sd.url = d.url)")
        end,
        timeout: :infinity
      )

    length(links)
  end

  @doc "The document URLs a listing points at, from the last discovery."
  def linked_urls(%Server{id: id}) do
    from(sd in "server_documents", where: sd.server_id == ^id, select: sd.url) |> Repo.all()
  end

  # --- Checking --------------------------------------------------------------

  @doc """
  Checks one batch of due documents and returns a tally of outcomes.
  Options: `:limit`, `:concurrency`, `:recheck_days`.
  """
  def check_batch(opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_batch)
    concurrency = Keyword.get(opts, :concurrency, @default_concurrency)

    cutoff =
      DateTime.add(
        DateTime.utc_now(),
        -Keyword.get(opts, :recheck_days, @default_recheck_days) * 86_400
      )

    Document
    |> where([d], is_nil(d.checked_at) or d.checked_at < ^cutoff)
    |> order_by([d], asc_nulls_first: d.checked_at, asc: d.id)
    |> limit(^limit)
    |> Repo.all()
    |> Task.async_stream(&check/1,
      max_concurrency: concurrency,
      timeout: 60_000,
      on_timeout: :kill_task
    )
    |> Enum.map(fn
      {:ok, outcome} -> outcome
      {:exit, _} -> :error
    end)
    |> Enum.frequencies()
  end

  @doc "Fetches one document, records any change, and returns what happened."
  def check(%Document{} = doc) do
    now = DateTime.utc_now()

    case fetch(doc.url, conditional_headers(doc), @max_redirects) do
      :not_modified ->
        update!(doc, %{checked_at: now, last_error: nil})
        :not_modified

      {:ok, body, resp} ->
        present(doc, body, resp, now)

      :missing ->
        missing(doc, now)

      {:error, reason} ->
        # An outage is not a removal: keep what was known.
        update!(doc, %{checked_at: now, last_error: String.slice(reason, 0, 500)})
        :error
    end
  end

  defp present(doc, body, resp, now) do
    sha = :crypto.hash(:sha256, body) |> Base.encode16(case: :lower)

    validators = %{
      status: "ok",
      etag: header(resp, "etag"),
      last_modified: header(resp, "last-modified"),
      checked_at: now,
      last_error: nil
    }

    fresh = Map.merge(validators, %{content: body, sha256: sha, changed_at: now})

    cond do
      doc.status == "ok" and doc.sha256 == sha ->
        update!(doc, validators)
        :unchanged

      doc.status == "ok" ->
        {added, removed} = line_diff(doc.content || "", body)
        Changes.record_document(doc.url, doc.kind, %{added: added, removed: removed})
        update!(doc, fresh)
        :changed

      doc.status == "missing" ->
        Changes.record_document(doc.url, doc.kind, %{
          added: body |> lines() |> cap(),
          fields: %{"file" => ["absent", "published"]}
        })

        update!(doc, fresh)
        :changed

      true ->
        # First sight: a baseline, not an event.
        update!(doc, fresh)
        :baseline
    end
  end

  defp missing(%Document{status: "ok"} = doc, now) do
    Changes.record_document(doc.url, doc.kind, %{
      removed: (doc.content || "") |> lines() |> cap(),
      fields: %{"file" => ["published", "removed"]}
    })

    update!(doc, gone(now))
    :changed
  end

  defp missing(doc, now) do
    update!(doc, gone(now))
    :missing
  end

  defp gone(now) do
    %{
      status: "missing",
      content: nil,
      sha256: nil,
      etag: nil,
      last_modified: nil,
      checked_at: now,
      last_error: nil
    }
  end

  defp update!(doc, attrs), do: doc |> Ecto.Changeset.change(attrs) |> Repo.update!()

  # --- Diffing ---------------------------------------------------------------

  defp line_diff(old, new) do
    old
    |> lines()
    |> List.myers_difference(lines(new))
    |> Enum.reduce({[], []}, fn
      {:ins, ls}, {added, removed} -> {[ls | added], removed}
      {:del, ls}, {added, removed} -> {added, [ls | removed]}
      {:eq, _}, acc -> acc
    end)
    |> then(fn {added, removed} ->
      {added |> Enum.reverse() |> List.flatten() |> cap(),
       removed |> Enum.reverse() |> List.flatten() |> cap()}
    end)
  end

  # Blank lines are dropped: whitespace reflows would otherwise fill a
  # changelog with nothing.
  defp lines(text) do
    text
    |> String.split(["\r\n", "\n"])
    |> Enum.map(&String.trim_trailing/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp cap(lines),
    do: lines |> Enum.take(@diff_lines) |> Enum.map(&String.slice(&1, 0, @line_chars))

  # --- Fetching --------------------------------------------------------------

  defp conditional_headers(%Document{status: "ok"} = doc) do
    [{"if-none-match", doc.etag}, {"if-modified-since", doc.last_modified}]
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
  end

  defp conditional_headers(_), do: []

  defp fetch(_url, _headers, hops) when hops < 0, do: {:error, "too many redirects"}

  defp fetch(url, headers, hops) do
    with {:ok, uri} <- safe_uri(url),
         :ok <- public_host(uri.host) do
      case request(url, headers) do
        {:ok, %Req.Response{status: 304}} ->
          :not_modified

        {:ok, %Req.Response{status: status} = resp} when status in [301, 302, 303, 307, 308] ->
          case header(resp, "location") do
            nil -> {:error, "redirect without location"}
            location -> fetch(URI.merge(url, location) |> URI.to_string(), headers, hops - 1)
          end

        {:ok, %Req.Response{status: 200, body: body} = resp} ->
          if text?(resp, body), do: {:ok, body, resp}, else: :missing

        {:ok, %Req.Response{status: status}} when status in [404, 410] ->
          :missing

        {:ok, %Req.Response{status: status}} ->
          {:error, "HTTP #{status}"}

        {:error, exception} ->
          {:error, Exception.message(exception)}
      end
    end
  end

  defp safe_uri(url) do
    case URI.parse(url) do
      %URI{scheme: "https", host: host, port: 443} = uri when is_binary(host) and host != "" ->
        {:ok, uri}

      _ ->
        {:error, "not an https URL on the default port"}
    end
  end

  defp request(url, headers) do
    Req.get(
      url,
      [
        redirect: false,
        retry: false,
        decode_body: false,
        receive_timeout: 10_000,
        connect_options: [timeout: 5_000],
        headers: [
          {"user-agent",
           "MCPHarbor/#{Application.spec(:mcp_registry, :vsn)} (+#{McpRegistryWeb.Endpoint.url()})"},
          {"accept", "text/markdown, text/plain;q=0.9, */*;q=0.1"} | headers
        ],
        # Stop reading at the cap rather than downloading everything first.
        into: fn {:data, chunk}, {req, resp} ->
          body = (resp.body || "") <> chunk

          if byte_size(body) >= @max_bytes,
            do: {:halt, {req, %{resp | body: binary_part(body, 0, @max_bytes)}}},
            else: {:cont, {req, %{resp | body: body}}}
        end
      ] ++ config(:req_options, [])
    )
  end

  defp text?(resp, body) do
    type = resp |> header("content-type") |> to_string() |> String.downcase()

    head =
      body
      |> binary_part(0, min(byte_size(body), 512))
      |> String.trim_leading()
      |> String.downcase()

    String.valid?(body) and not String.contains?(type, "html") and
      not String.starts_with?(head, ["<!doctype", "<html", "<?xml", "<head"]) and
      not json?(type, body)
  end

  # The other catch-all: an API host answering every path with a JSON status
  # document. Neither llms.txt nor AGENTS.md is JSON, and one that carries a
  # timestamp would otherwise "change" on every check.
  defp json?(type, body) do
    String.contains?(type, "json") or
      (String.starts_with?(String.trim_leading(body), ["{", "["]) and
         match?({:ok, _}, Jason.decode(body)))
  end

  defp header(%Req.Response{} = resp, name) do
    case Req.Response.get_header(resp, name) do
      [value | _] -> value
      [] -> nil
    end
  end

  # --- Refusing private addresses -------------------------------------------

  defp public_host(host) do
    resolver = config(:resolver, &resolve/1)

    case resolver.(host) do
      {:ok, []} ->
        {:error, "#{host} does not resolve"}

      {:ok, addresses} ->
        if Enum.all?(addresses, &public_address?/1),
          do: :ok,
          else: {:error, "#{host} resolves to a private address"}

      {:error, _} ->
        {:error, "#{host} does not resolve"}
    end
  end

  defp resolve(host) do
    charlist = String.to_charlist(host)

    v4 =
      case :inet.getaddrs(charlist, :inet) do
        {:ok, addrs} -> addrs
        _ -> []
      end

    v6 =
      case :inet.getaddrs(charlist, :inet6) do
        {:ok, addrs} -> addrs
        _ -> []
      end

    {:ok, v4 ++ v6}
  end

  @doc false
  def public_address?({a, b, _, _}) do
    not (a in [0, 10, 127] or a >= 224 or
           (a == 100 and b in 64..127) or
           (a == 169 and b == 254) or
           (a == 172 and b in 16..31) or
           (a == 192 and b == 168) or
           (a == 198 and b in 18..19))
  end

  def public_address?({0, 0, 0, 0, 0, 0, 0, 1}), do: false
  def public_address?({0, 0, 0, 0, 0, 0, 0, 0}), do: false
  # IPv4-mapped (::ffff:a.b.c.d): judge the IPv4 address inside it.
  def public_address?({0, 0, 0, 0, 0, 0xFFFF, hi, lo}),
    do: public_address?({div(hi, 256), rem(hi, 256), div(lo, 256), rem(lo, 256)})

  def public_address?({first, _, _, _, _, _, _, _}) do
    # fc00::/7 unique-local, fe80::/10 link-local, ff00::/8 multicast.
    not (Bitwise.band(first, 0xFE00) == 0xFC00 or Bitwise.band(first, 0xFFC0) == 0xFE80 or
           Bitwise.band(first, 0xFF00) == 0xFF00)
  end

  defp config(key, default),
    do: Keyword.get(Application.get_env(:mcp_registry, :documents, []), key, default)
end
