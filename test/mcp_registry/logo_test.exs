defmodule McpRegistry.Registry.LogoTest do
  use ExUnit.Case, async: true

  alias McpRegistry.Registry.Logo
  alias McpRegistry.Registry.Server

  defp server(attrs), do: struct(Server, Map.merge(%{name: "com.acme/thing"}, attrs))

  describe "which logo a listing gets" do
    test "a declared icon outranks everything" do
      s = server(%{name: "io.github.acme/x", icon_url: "https://acme.test/logo.svg"})
      assert Logo.for_server(s) == {:declared, "https://acme.test/logo.svg"}
    end

    test "an io.github namespace gets that verified owner's avatar" do
      assert {:github, url} = Logo.for_server(server(%{name: "io.github.troyhunt/hibp"}))
      assert url == "https://github.com/troyhunt.png?size=96"
    end

    test "a domain namespace falls back to its repository owner" do
      s = server(%{repository_url: "https://github.com/cloudflare/mcp-server-cloudflare"})
      assert {:repository, url} = Logo.for_server(s)
      assert url =~ "/cloudflare.png?"
    end

    test "the namespace beats the repository, because only it is verified" do
      s = server(%{name: "io.github.alice/x", repository_url: "https://github.com/bob/x"})
      assert {:github, url} = Logo.for_server(s)
      assert url =~ "/alice.png?"
    end

    test "nothing on the record means no logo, never a guess" do
      assert Logo.for_server(server(%{repository_url: "https://gitlab.com/acme/x"})) == nil
      assert Logo.for_server(server(%{})) == nil
    end

    test "a login GitHub would reject is not turned into a URL" do
      assert Logo.namespace_login("io.github.-bad/x") == nil
      assert Logo.namespace_login("io.github.a--b/x") == nil
      assert Logo.repository_login("https://github.com/") == nil
    end
  end

  describe "choosing from a server.json icons array" do
    test "SVG first, since it is sharp at any size" do
      icons = [
        %{"src" => "https://a.test/128.png", "sizes" => ["128x128"]},
        %{"src" => "https://a.test/mark.svg", "mimeType" => "image/svg+xml"}
      ]

      assert Logo.pick(icons) == "https://a.test/mark.svg"
    end

    test "otherwise the smallest raster that is still big enough" do
      icons = [
        %{"src" => "https://a.test/512.png", "sizes" => ["512x512"]},
        %{"src" => "https://a.test/32.png", "sizes" => ["32x32"]},
        %{"src" => "https://a.test/180.png", "sizes" => ["180x180"]}
      ]

      assert Logo.pick(icons) == "https://a.test/180.png"
    end

    test "an icon for dark backgrounds is passed over when there is another" do
      icons = [
        %{"src" => "https://a.test/dark.svg", "theme" => "dark"},
        %{"src" => "https://a.test/light.png", "sizes" => ["256x256"]}
      ]

      assert Logo.pick(icons) == "https://a.test/light.png"
    end

    test "unusable sources are dropped: http, data:, placeholders, junk" do
      assert Logo.pick([%{"src" => "http://a.test/x.png"}]) == nil
      assert Logo.pick([%{"src" => "data:image/png;base64,AAAA"}]) == nil
      assert Logo.pick([%{"src" => "https://{HOST}/x.png"}]) == nil
      assert Logo.pick([%{"nope" => 1}, "string", nil]) == nil
      assert Logo.pick(nil) == nil
    end
  end
end
