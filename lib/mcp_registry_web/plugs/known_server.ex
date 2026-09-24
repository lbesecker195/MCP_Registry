defmodule McpRegistryWeb.Plugs.KnownServer do
  @moduledoc """
  Sends a request for a listing that does not exist to the home page, with a
  301, before `ServerLive.Show` has a chance to raise.

  This has to run as a plug rather than inside the LiveView. A LiveView that
  redirects from `mount/3` answers the initial HTTP request with a **302**,
  and the requirement here is a permanent redirect — so the decision has to be
  made while it is still an ordinary `Plug.Conn`.

  The cost is one indexed existence check on the detail route. The LiveView
  still loads the row itself; `conn.assigns` cannot be handed to `mount/3`, so
  there is no way to share the result without routing the page through a
  controller instead.

  Only the initial page load passes through here. A live navigation to a
  missing listing raises inside the LiveView as before, the client reconnects
  with a full request, and that request lands on this plug.
  """
  @behaviour Plug

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  alias McpRegistry.Registry

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Plug.Conn{path_info: ["servers" | segments]} = conn, _opts)
      when segments != [] do
    # The first two segments are the listing; anything after is a sub-page such
    # as /tools or /tools/<tool>/<client>. A name is always exactly
    # `namespace/short-name` -- the changeset regex allows one slash and no more
    # -- so taking two is not a guess. Joining every segment instead would make
    # each sub-page look like a listing that does not exist, and 301 it home.
    if Registry.server_exists?(segments |> Enum.take(2) |> Enum.join("/")) do
      conn
    else
      conn
      |> put_status(:moved_permanently)
      |> redirect(to: "/")
      |> halt()
    end
  end

  @impl Plug
  def call(conn, _opts), do: conn
end
