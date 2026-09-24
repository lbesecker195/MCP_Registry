defmodule McpRegistryWeb.ServerLive.SkillsTest do
  use McpRegistryWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import McpRegistry.RegistryFixtures

  defp with_skills(prompts \\ ~w(review_diff summarise_issue)) do
    server_fixture(%{title: "Weather", prompts: prompts, tools: ~w(get_forecast)})
  end

  describe "the skills index" do
    test "lists every skill and links each one", %{conn: conn} do
      server = with_skills()
      {:ok, _view, html} = live(conn, "/servers/#{server.name}/skills")

      assert html =~ "Weather MCP Skills"
      assert html =~ "review_diff"
      assert html =~ "summarise_issue"
      assert html =~ "/skills/review_diff"
    end

    test "a listing with no skills redirects rather than showing an empty page", %{conn: conn} do
      # The reason the prober was extended: without a count, every one of
      # 34,000 listings would have had a skills page with nothing on it.
      server = server_fixture(%{prompts: []})

      assert {:error, {:live_redirect, %{to: to}}} = live(conn, "/servers/#{server.name}/skills")
      assert to == "/servers/#{server.name}"
    end

    test "points at the tools silo and says how the two differ", %{conn: conn} do
      server = with_skills()
      {:ok, _view, html} = live(conn, "/servers/#{server.name}/skills")

      assert html =~ "/tools"
      assert html =~ "invoke"
    end
  end

  describe "a skill page" do
    test "names the skill and offers every client", %{conn: conn} do
      server = with_skills()
      {:ok, _view, html} = live(conn, "/servers/#{server.name}/skills/review_diff")

      assert html =~ "review_diff"

      for label <- ["Claude Code", "Cursor", "VS Code"] do
        assert html =~ "#{label} Weather Skill/review_diff"
      end
    end

    test "provenance says the names were read from the server", %{conn: conn} do
      server = with_skills()
      {:ok, _view, html} = live(conn, "/servers/#{server.name}/skills/review_diff")

      assert html =~ "prompts/list"
    end

    test "a skill that is not on this server redirects to the listing", %{conn: conn} do
      server = with_skills()

      assert {:error, {:live_redirect, %{to: to}}} =
               live(conn, "/servers/#{server.name}/skills/not_a_skill")

      assert to == "/servers/#{server.name}"
    end
  end

  describe "a skill-and-client page" do
    test "H1 and H2 follow the shapes that were asked for", %{conn: conn} do
      server = with_skills()
      {:ok, _view, html} = live(conn, "/servers/#{server.name}/skills/review_diff/cursor")

      assert html =~ ~r{<h1[^>]*>\s*Cursor Weather Skill/review_diff\s*</h1>}
      assert html =~ "How to: Cursor Weather review_diff"
    end

    test "carries that client's real configuration, not a generic one", %{conn: conn} do
      server = with_skills()

      {:ok, _view, vscode} = live(conn, "/servers/#{server.name}/skills/review_diff/vscode")
      assert vscode =~ "&quot;servers&quot;"
      refute vscode =~ "mcpServers"
    end

    test "says where the prompt actually surfaces in that client", %{conn: conn} do
      server = with_skills()

      {:ok, _view, code} = live(conn, "/servers/#{server.name}/skills/review_diff/claude-code")
      assert code =~ "slash command"
    end

    test "an unknown client falls back to the skill page", %{conn: conn} do
      server = with_skills()

      assert {:error, {:live_redirect, %{to: to}}} =
               live(conn, "/servers/#{server.name}/skills/review_diff/gptbot")

      assert to == "/servers/#{server.name}/skills/review_diff"
    end
  end

  test "an unknown listing still redirects home with a 301", %{conn: conn} do
    conn = get(conn, "/servers/io.github.nobody/nothing/skills")

    assert redirected_to(conn, 301) == "/"
  end

  test "the skills sitemap carries index, skill and client URLs", %{conn: conn} do
    server = with_skills(~w(review_diff))

    xml = conn |> get("/sitemaps/skills-1.xml") |> response(200)

    assert xml =~ "/servers/#{server.name}/skills</loc>"
    assert xml =~ "/servers/#{server.name}/skills/review_diff</loc>"
    assert xml =~ "/skills/review_diff/cursor</loc>"

    assert conn |> get("/sitemap.xml") |> response(200) =~ "/sitemaps/skills-1.xml"
  end

  test "no skills anywhere means no skills file in the index", %{conn: conn} do
    server_fixture(%{prompts: []})

    refute conn |> get("/sitemap.xml") |> response(200) =~ "skills-1.xml"
    assert conn |> get("/sitemaps/skills-1.xml") |> response(404) == ""
  end

  test "every page in the silo is indexable", %{conn: conn} do
    server = with_skills()

    for path <- ["/skills", "/skills/review_diff", "/skills/review_diff/cursor"] do
      html = conn |> get("/servers/#{server.name}#{path}") |> html_response(200)
      refute html =~ "noindex", "#{path} should be indexable"
    end
  end

  test "the listing page links into the silo only when there are skills", %{conn: conn} do
    with_skills()
    without = server_fixture(%{prompts: [], name: "io.github.acme/quiet"})

    {:ok, _view, quiet} = live(conn, "/servers/#{without.name}")
    refute quiet =~ "/skills"
  end
end
