defmodule McpRegistry.Registry.Tool do
  @moduledoc """
  What can be said about a tool when its name is all we have.

  The registry stores `tools` as a list of names. There are no schemas,
  descriptions or parameter lists: the official registry's `server.json` does
  not carry them, and only a live connection to the server would. So everything
  here is derived from the name itself and nothing is invented — the kind is
  read off the leading verb, and the gloss is the name with its punctuation
  removed.

  Shared by the detail page and the tool pages so the two cannot disagree about
  what a tool is.
  """

  @mutating ~w(create update delete remove write set add insert put patch
               send post publish merge push upload move rename execute run
               start stop restart cancel close edit append clear reset
               revoke assign apply install uninstall import sync)

  @readonly ~w(get list search read fetch find query describe show view
               lookup count check resolve inspect export download browse
               status)

  @doc """
  `:mutating`, `:readonly`, or `:unknown` when the leading verb says neither.

  A hint for a reader deciding what to grant, never a guarantee — a tool called
  `get_or_create_session` leads with `get` and still writes.
  """
  def kind(name) when is_binary(name) do
    verb = name |> String.downcase() |> String.split(~r/[^a-z0-9]+/, trim: true) |> List.first()

    cond do
      verb in @mutating -> :mutating
      verb in @readonly -> :readonly
      true -> :unknown
    end
  end

  @doc """
  The name as words: `create_or_update_file` becomes `create or update file`.

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

  @doc "A tool name turned into a URL segment, and back."
  def slug(name) when is_binary(name), do: name |> String.downcase() |> URI.encode()

  @doc """
  Finds the tool on a server whose slug matches, or `nil`.

  Matching on the slug rather than the raw name means a URL stays valid whatever
  casing the publisher used.
  """
  def find(tools, slug) when is_list(tools) and is_binary(slug) do
    wanted = String.downcase(slug)
    Enum.find(tools, fn tool -> String.downcase(tool) == wanted end)
  end
end
