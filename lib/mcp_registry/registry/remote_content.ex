defmodule McpRegistry.Registry.RemoteContent do
  @moduledoc """
  Live enrichment for a server show page.

  Pulls the first 200 words of a GitHub README when `repository_url` points at
  github.com, and the document title plus meta description from `website_url`.
  Failures are soft: the page still renders with whatever the listing already
  stored.
  """

  @word_limit 200
  @receive_timeout 5_000
  @connect_timeout 3_000
  @max_body 512_000

  @type t :: %{
          website_title: String.t() | nil,
          website_description: String.t() | nil,
          readme_excerpt: String.t() | nil,
          readme_url: String.t() | nil
        }

  @doc "Fetches website meta and a GitHub README excerpt for a server listing."
  def fetch(%{repository_url: repo, website_url: site}) do
    %{
      website_title: nil,
      website_description: nil,
      readme_excerpt: nil,
      readme_url: nil
    }
    |> maybe_put_website(site)
    |> maybe_put_readme(repo)
  end

  def fetch(_), do: fetch(%{repository_url: nil, website_url: nil})

  defp maybe_put_website(acc, url) when is_binary(url) and url != "" do
    case fetch_website_meta(url) do
      {:ok, title, description} ->
        %{acc | website_title: title, website_description: description}

      :error ->
        acc
    end
  end

  defp maybe_put_website(acc, _), do: acc

  defp maybe_put_readme(acc, url) when is_binary(url) and url != "" do
    case fetch_readme_excerpt(url) do
      {:ok, excerpt, raw_url} ->
        %{acc | readme_excerpt: excerpt, readme_url: raw_url}

      :error ->
        acc
    end
  end

  defp maybe_put_readme(acc, _), do: acc

  defp fetch_website_meta(url) do
    with {:ok, %Req.Response{status: 200, body: body}} when is_binary(body) <-
           get(url, decode_body: false),
         html when is_binary(html) <- truncate_body(body) do
      title = extract_title(html)
      description = extract_description(html)

      if is_nil(title) and is_nil(description),
        do: :error,
        else: {:ok, title, description}
    else
      _ -> :error
    end
  rescue
    _ -> :error
  catch
    _, _ -> :error
  end

  defp fetch_readme_excerpt(repo_url) do
    case github_readme_candidates(repo_url) do
      [] ->
        :error

      candidates ->
        Enum.find_value(candidates, :error, fn raw_url ->
          case get(raw_url, decode_body: false) do
            {:ok, %Req.Response{status: 200, body: body}} when is_binary(body) ->
              excerpt =
                body
                |> truncate_body()
                |> strip_frontmatter()
                |> first_words(@word_limit)

              if excerpt == "", do: nil, else: {:ok, excerpt, raw_url}

            _ ->
              nil
          end
        end)
    end
  rescue
    _ -> :error
  catch
    _, _ -> :error
  end

  defp get(url, opts) do
    Req.get(
      url,
      [
        receive_timeout: @receive_timeout,
        connect_options: [timeout: @connect_timeout],
        retry: false,
        redirect: true,
        headers: [{"user-agent", user_agent()}, {"accept", "*/*"}]
      ] ++ opts
    )
  end

  defp user_agent do
    "mcp-registry/#{Application.spec(:mcp_registry, :vsn)} (+#{McpRegistryWeb.Endpoint.url()})"
  end

  defp truncate_body(body) when byte_size(body) > @max_body, do: binary_part(body, 0, @max_body)
  defp truncate_body(body), do: body

  # github.com/owner/repo[/... ] → raw.githubusercontent.com/owner/repo/HEAD/README.md
  defp github_readme_candidates(url) do
    uri = URI.parse(String.trim(url))

    if uri.host in ["github.com", "www.github.com"] do
      path =
        (uri.path || "/")
        |> String.trim("/")
        |> String.replace_suffix(".git", "")

      case String.split(path, "/", trim: true) do
        [owner, repo | _] when owner != "" and repo != "" ->
          base = "https://raw.githubusercontent.com/#{owner}/#{repo}/HEAD"

          for name <- ~w(README.md README.MD Readme.md readme.md README.markdown README) do
            base <> "/" <> name
          end

        _ ->
          []
      end
    else
      []
    end
  end

  defp strip_frontmatter(text) do
    case String.split(text, ~r/^---\s*$/m, parts: 3) do
      ["", _front, rest] -> String.trim_leading(rest)
      _ -> text
    end
  end

  defp first_words(text, limit) do
    words = String.split(text, ~r/\s+/u, trim: true)

    words
    |> Enum.take(limit)
    |> Enum.join(" ")
    |> then(fn excerpt ->
      if length(words) > limit, do: excerpt <> "…", else: excerpt
    end)
  end

  defp extract_title(html) do
    cond do
      og = meta_content(html, "property", "og:title") -> clean_text(og)
      tw = meta_content(html, "name", "twitter:title") -> clean_text(tw)
      match = Regex.run(~r/<title[^>]*>(.*?)<\/title>/is, html, capture: :all_but_first) ->
        match |> hd() |> clean_text()
      true -> nil
    end
  end

  defp extract_description(html) do
    cond do
      og = meta_content(html, "property", "og:description") -> clean_text(og)
      desc = meta_content(html, "name", "description") -> clean_text(desc)
      tw = meta_content(html, "name", "twitter:description") -> clean_text(tw)
      true -> nil
    end
  end

  # Meta tags put content= before or after name=/property=.
  defp meta_content(html, attr, value) do
    patterns = [
      ~r/<meta\b[^>]*\b#{attr}\s*=\s*["']#{Regex.escape(value)}["'][^>]*\bcontent\s*=\s*["']([^"']+)["'][^>]*>/i,
      ~r/<meta\b[^>]*\bcontent\s*=\s*["']([^"']+)["'][^>]*\b#{attr}\s*=\s*["']#{Regex.escape(value)}["'][^>]*>/i
    ]

    Enum.find_value(patterns, fn pattern ->
      case Regex.run(pattern, html, capture: :all_but_first) do
        [content] -> content
        _ -> nil
      end
    end)
  end

  defp clean_text(nil), do: nil

  defp clean_text(text) do
    text
    |> String.replace(~r/<[^>]+>/, "")
    |> String.replace("&nbsp;", " ")
    |> String.replace("&amp;", "&")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&#39;", "'")
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
    |> case do
      "" -> nil
      cleaned -> cleaned
    end
  end
end
