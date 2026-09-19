defmodule McpRegistryWeb.RedirectController do
  @moduledoc """
  Catches everything the router did not match.

  Browser requests are sent to the home page permanently, rather than shown a
  404. The JSON API keeps answering 404, because an API client that follows a
  redirect into an HTML page gets a confusing parse error instead of a clear
  miss.
  """
  use McpRegistryWeb, :controller

  @doc "Permanently redirects any unmatched browser URL to the home page."
  def home(conn, _params) do
    conn
    |> put_status(:moved_permanently)
    |> redirect(to: ~p"/")
  end

  @doc "Answers unmatched API paths with a 404 rather than a redirect."
  def api_not_found(conn, _params) do
    conn
    |> put_status(:not_found)
    |> put_view(json: McpRegistryWeb.ErrorJSON)
    |> render(:"404")
  end
end
