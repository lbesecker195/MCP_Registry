defmodule McpRegistry.Registry.Logo do
  @moduledoc """
  Which image stands for a listing, and where it came from.

  In order of preference:

    1. **The icon the publisher declared** in `server.json`. It is the logo
       they chose for this server specifically, so nothing outranks it.
    2. **The GitHub avatar of an `io.github.*` namespace owner.** The official
       registry only lets someone publish under `io.github.acme` after they
       have proved they are `acme` on GitHub, so this is a verified identity
       rather than a claim. Two listings in three have one.
    3. **The GitHub avatar of the repository owner**, for listings under a
       domain namespace that point at a GitHub repository. Weaker: the
       repository URL is the publisher's own say-so. It is still their public
       profile image and never someone else's, so it is used, last.
    4. Nothing, in which case the page draws the name's monogram.

  Every source here is something the publisher put on the public record. Logos
  are never guessed from a name or scraped from a website, because a wrong logo
  is worse than none: it asserts an affiliation that is not there.
  """

  alias McpRegistry.Registry.Server

  # GitHub's own rule for a login: alphanumerics and single hyphens, up to 39.
  @github_login ~r/\A[a-z0-9](?:[a-z0-9]|-(?=[a-z0-9])){0,38}\z/i

  # Twice the largest size a logo is drawn at, for high-density screens. Avatars
  # at this size are around 2 KB.
  @avatar_px 96

  @doc """
  The logo for a listing as `{source, url}`, or `nil` when there is none.

  `source` is `:declared`, `:github` or `:repository` -- see the moduledoc for
  what each means and why they rank as they do.
  """
  def for_server(%Server{} = server) do
    cond do
      usable_src?(server.icon_url) -> {:declared, server.icon_url}
      login = namespace_login(server.name) -> {:github, avatar(login)}
      login = repository_login(server.repository_url) -> {:repository, avatar(login)}
      true -> nil
    end
  end

  @doc """
  Chooses one icon from a `server.json` `icons` array, or `nil`.

  The array follows the MCP `Icon` shape: `src`, and optionally `mimeType`,
  `sizes` and `theme`. Preference goes to a scalable SVG, then to the smallest
  raster that is still at least #{@avatar_px}px -- a 512px PNG drawn at 48px is
  a large download for no visible gain. An icon meant for dark backgrounds is
  passed over when another exists, because logos are drawn on a light tile.

  Only icons that `usable_src?/1` accepts are considered, so a bad icon is
  dropped here rather than failing the listing's import.
  """
  def pick(icons) when is_list(icons) do
    icons
    |> Enum.filter(&(is_map(&1) and usable_src?(&1["src"])))
    |> Enum.sort_by(&rank/1)
    |> List.first()
    |> case do
      %{"src" => src} -> src
      nil -> nil
    end
  end

  def pick(_), do: nil

  @doc """
  Whether a URL can be used as an `<img src>` on this site.

  https only: the pages are served over https, so a plain-http image is
  blocked as mixed content. No `data:` URIs either -- they would put
  publisher-supplied payloads of any size straight into our HTML.
  """
  def usable_src?(src) when is_binary(src) do
    byte_size(src) <= 2048 and
      match?(
        %URI{scheme: "https", host: host} when is_binary(host) and host != "",
        URI.parse(src)
      ) and
      not String.contains?(src, ["{", "}", " "])
  end

  def usable_src?(_), do: false

  @doc "The GitHub login an `io.github.<login>/...` name was verified for, or `nil`."
  def namespace_login("io.github." <> rest) do
    rest |> String.split("/", parts: 2) |> List.first() |> valid_login()
  end

  def namespace_login(_), do: nil

  @doc "The owner of a `https://github.com/<owner>/<repo>` URL, or `nil`."
  def repository_login(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{host: host, path: "/" <> path} when host in ["github.com", "www.github.com"] ->
        path |> String.split("/", parts: 2) |> List.first() |> valid_login()

      _ ->
        nil
    end
  end

  def repository_login(_), do: nil

  defp valid_login(login) when is_binary(login) do
    if Regex.match?(@github_login, login), do: String.downcase(login), else: nil
  end

  defp valid_login(_), do: nil

  # avatars.githubusercontent.com answers a login directly with the image, no
  # redirect -- github.com/<login>.png costs an extra round trip per logo.
  defp avatar(login), do: "https://avatars.githubusercontent.com/#{login}?size=#{@avatar_px}"

  # Lower sorts first. Dark-theme icons last; then SVG; then the smallest
  # raster that is big enough; then any raster; unknown sizes in the middle.
  defp rank(icon) do
    dark = if icon["theme"] == "dark", do: 1, else: 0
    {dark, size_rank(icon)}
  end

  defp size_rank(icon) do
    svg? =
      icon["mimeType"] == "image/svg+xml" or
        String.ends_with?(String.downcase(icon["src"]), ".svg") or
        "any" in List.wrap(icon["sizes"])

    px = largest_px(icon["sizes"])

    cond do
      svg? -> 0
      # Big enough: the smaller the better, so a 128px beats a 512px.
      is_integer(px) and px >= @avatar_px -> 1 + px / 10_000
      is_nil(px) -> 2
      # Too small to look sharp, but better than nothing; larger first.
      true -> 3 + 1 / max(px, 1)
    end
  end

  defp largest_px(sizes) when is_list(sizes) do
    sizes
    |> Enum.flat_map(fn
      size when is_binary(size) ->
        case Regex.run(~r/\A(\d+)x(\d+)\z/, size) do
          [_, w, h] -> [min(String.to_integer(w), String.to_integer(h))]
          _ -> []
        end

      _ ->
        []
    end)
    |> Enum.max(fn -> nil end)
  end

  defp largest_px(_), do: nil
end
