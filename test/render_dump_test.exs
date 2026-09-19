defmodule McpRegistryWeb.RenderDumpTest do
  @moduledoc """
  Not a test: a way to look at a page.

  Renders each page through the normal LiveView stack and writes it to
  `tmp/render/`, with `assets/css/app.css` inlined so the file opens straight
  from disk. Tailwind still comes from the CDN, so open it in a browser with a
  network connection.

      mix test --include render_dump test/render_dump_test.exs

  It is excluded from `mix test` by default.
  """
  use McpRegistryWeb.ConnCase, async: false

  @moduletag :render_dump

  import Phoenix.LiveViewTest
  import McpRegistry.RegistryFixtures

  @out "tmp/render"

  setup do
    File.mkdir_p!(@out)
    :ok
  end

  test "dump the redesigned pages", %{conn: conn} do
    server =
      server_fixture(%{
        name: "io.github.github/github-mcp",
        title: "GitHub",
        description:
          "Standard Model Context Protocol interface exposing repositories, commit history, " <>
            "issue tracking and pull request mutations directly to LLM agents.",
        version: "0.6.2",
        package_registry: "npm",
        package_identifier: "@github/github-mcp-server",
        env_vars: ["GITHUB_PERSONAL_ACCESS_TOKEN"],
        tags: ~w(developer-tools git github issues),
        tools: ~w(create_or_update_file search_repositories get_file_contents
                  create_pull_request list_issues delete_branch update_issue
                  push_files fork_repository merge_pull_request)
      })

    for _ <- 1..5, do: server_fixture()

    {:ok, _view, detail} = live(conn, "/servers/#{server.name}")
    {:ok, _view, catalogue} = live(conn, ~p"/servers")
    {:ok, _view, landing} = live(conn, ~p"/")

    dump("detail", detail)
    dump("catalogue", catalogue)
    dump("landing", landing)
  end

  # The page links `/assets/css/app.css`, which a file:// URL cannot resolve,
  # so the tokens are inlined. Everything else is left exactly as rendered.
  defp dump(name, html) do
    css = File.read!("assets/css/app.css")

    html =
      String.replace(
        html,
        ~r{<link[^>]*href="/assets/css/app\.css"[^>]*/?>},
        "<style>#{css}</style>"
      )

    File.write!(Path.join(@out, "#{name}.html"), html)
  end
end
