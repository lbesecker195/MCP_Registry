defmodule McpRegistryWeb.GoogleTagTest do
  use McpRegistryWeb.ConnCase, async: true

  import Phoenix.Template, only: [render_to_string: 4]

  @loader "https://www.googletagmanager.com/gtag/js?id=G-JL6M1013R2"

  # The site has two <head>s: the root layout and the standalone error page.
  # Google Analytics has to be in both, or 404s go uncounted.
  test "every page through the root layout carries the tag", %{conn: conn} do
    html = conn |> get(~p"/servers") |> html_response(200)
    [head] = Regex.run(~r|<head>.*?</head>|s, html)

    assert head =~ @loader
    assert head =~ "gtag('config', 'G-JL6M1013R2')"
  end

  test "the error page carries the tag" do
    html = render_to_string(McpRegistryWeb.ErrorHTML, "404", "html", [])
    [head] = Regex.run(~r|<head>.*?</head>|s, html)

    assert head =~ @loader
    assert head =~ "gtag('config', 'G-JL6M1013R2')"
  end
end
