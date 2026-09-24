defmodule McpRegistry.Registry.Capability do
  @moduledoc """
  What can be said about a prompt or a resource when its name is all we have.

  The two silos share this because they share a problem: only names are
  stored. Prompts carry arguments over the wire and resources carry a MIME
  type and description, and none of it is kept, so nothing here asserts more
  than the name supports.

  ## Why prompts and resources, and not "skills"

  These are the names MCP uses and the names people search for. A prompt is
  something the user invokes; a resource is data the client attaches as
  context. Calling either a skill would invent a word the protocol does not
  have and no reader is looking for.

  ## Where the names come from

  Nothing declares them. `server.json` has no field for prompts or resources,
  so unlike tools there is no publisher claim — every name was read from a
  live server by `McpRegistry.Probe`.
  """

  @doc """
  A name turned into one URL segment.

  Resources are the reason this is not `URI.encode/1`: a resource is
  identified by URI, and `URI.encode/1` leaves `/` alone, so
  `file:///readme.md` would have become three path segments and matched no
  route. Everything outside `[a-z0-9]` collapses to a hyphen instead.

  `http://` and `https://` are dropped because they carry no meaning in a
  slug and cost length. Other schemes stay: `file`, `ui` and `s3` distinguish
  resources that would otherwise read alike.

  Two names can in principle collide — `review_diff` and `review-diff`, or
  the same URL under both http and https. `find/2` then answers with the
  first, which is a worse page than it could be but never a wrong one.
  """
  def slug(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace(~r{^https?://}, "")
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
    |> String.slice(0, 120)
    |> case do
      "" -> "item"
      slug -> slug
    end
  end

  @doc """
  Finds the entry whose slug matches, or `nil`.

  Compares slug to slug rather than slug to raw name, so a name that the slug
  rewrites — every resource URI, and any prompt with punctuation in it — is
  still reachable from its own URL.
  """
  def find(items, requested) when is_list(items) and is_binary(requested) do
    wanted = slug(requested)
    Enum.find(items, fn item -> slug(item) == wanted end)
  end

  @doc """
  A prompt name as words: `review_pull_request` becomes `review pull request`.

  A pure transformation of the name, so it adds readability without asserting
  anything the registry does not know.
  """
  def gloss(name) when is_binary(name) do
    name
    |> String.replace(~r/[_\-.]+/, " ")
    |> String.replace(~r/([a-z0-9])([A-Z])/, "\\1 \\2")
    |> String.downcase()
    |> String.trim()
  end

  @doc """
  A resource URI shortened for display, without misrepresenting it.

  The scheme goes for `http` and `https` only, and a long URI is cut at the
  end with an ellipsis so it is visibly incomplete rather than quietly wrong.
  """
  def short_uri(uri) when is_binary(uri) do
    trimmed = String.replace(uri, ~r{^https?://}, "")

    if String.length(trimmed) > 72 do
      String.slice(trimmed, 0, 71) <> "…"
    else
      trimmed
    end
  end

  @doc "The scheme of a resource URI (`file`, `https`, `ui`), or `nil`."
  def scheme(uri) when is_binary(uri) do
    case Regex.run(~r{^([a-z][a-z0-9+.\-]*)://}i, uri) do
      [_, scheme] -> String.downcase(scheme)
      _ -> nil
    end
  end
end
