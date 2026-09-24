defmodule McpRegistry.Registry.Skill do
  @moduledoc """
  What can be said about a skill when its name is all we have.

  A skill here is an MCP **prompt**: a named, invocable capability a server
  offers, which a user picks deliberately rather than the model calling it on
  its own. That is the primitive closest to what people mean by a skill, and
  the distinction from a tool is the one worth drawing on the page — a tool is
  something the model reaches for, a prompt is something the user invokes.

  As with `McpRegistry.Registry.Tool`, only names are stored. Prompts carry
  arguments and a description over the wire, and neither is kept, so nothing
  here asserts more than the name supports: the gloss is the name with its
  punctuation removed, and that is all.

  ## Where the names come from

  Nothing declares prompts. `server.json` has no field for them, so unlike
  tools there is no publisher claim — every name here was read from a live
  server by `McpRegistry.Probe`. A listing with no skills page is a listing
  that answered and had none, or was never reachable.
  """

  @doc """
  The name as words: `review_pull_request` becomes `review pull request`.

  A pure transformation, so it adds readability without asserting anything the
  registry does not know.
  """
  def gloss(name) when is_binary(name) do
    name
    |> String.replace(~r/[_\-.\/]+/, " ")
    |> String.replace(~r/([a-z0-9])([A-Z])/, "\\1 \\2")
    |> String.downcase()
    |> String.trim()
  end

  @doc "A skill name turned into a URL segment."
  def slug(name) when is_binary(name), do: name |> String.downcase() |> URI.encode()

  @doc """
  Finds the skill on a server whose slug matches, or `nil`.

  Matching on the slug rather than the raw name means a URL stays valid
  whatever casing the publisher used.
  """
  def find(skills, slug) when is_list(skills) and is_binary(slug) do
    wanted = String.downcase(slug)
    Enum.find(skills, fn skill -> String.downcase(skill) == wanted end)
  end
end
