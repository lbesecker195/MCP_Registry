defmodule McpRegistryWeb.Plugs.IndexNowKey do
  @moduledoc """
  Answers `GET /<key>.txt` with the IndexNow key, which is how Bing, Yandex
  and the other IndexNow engines confirm that submissions from
  `McpRegistry.Discovery` come from whoever runs this host.

  This is a plug and not a route because the file name is the key itself,
  which comes from runtime config, and a router cannot match on that. It sits
  ahead of the router so the site-wide 301 home never swallows the check.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(%Plug.Conn{method: method, path_info: [file]} = conn, _opts)
      when method in ["GET", "HEAD"] do
    # The suffix test first, so most pages never hash the key.
    if String.ends_with?(file, ".txt") and file == McpRegistry.Discovery.indexnow_key() <> ".txt" do
      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(200, McpRegistry.Discovery.indexnow_key())
      |> halt()
    else
      conn
    end
  end

  def call(conn, _opts), do: conn
end
