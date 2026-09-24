defmodule McpRegistry.RegistryFixtures do
  @moduledoc "Test helpers for creating registry entities."

  def valid_server_attrs(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    Enum.into(attrs, %{
      name: "io.github.acme/weather-#{unique}",
      title: "Weather #{unique}",
      description: "Forecasts and severe-weather alerts by location.",
      version: "1.2.3",
      transport: "stdio",
      package_registry: "npm",
      package_identifier: "@acme/weather-mcp",
      env_vars: ["WEATHER_API_KEY"],
      tags: ["weather", "data"],
      tools: ["get_forecast", "get_alerts"],
      repository_url: "https://github.com/acme/weather-mcp",
      license: "MIT"
    })
  end

  def server_fixture(attrs \\ %{}) do
    status = Map.get(attrs, :status, "active")
    probed = Map.take(attrs, [:prompts, :resources])

    {:ok, server} =
      attrs
      |> Map.drop([:prompts, :resources])
      |> valid_server_attrs()
      |> McpRegistry.Registry.create_server(status: status)

    # Prompts and resources are deliberately not castable: the skills pages say
    # these names were read from the server itself, and a publisher able to
    # submit them would make that claim false. The probe writes them straight
    # through, so a fixture has to as well.
    if probed == %{} do
      server
    else
      server
      |> Ecto.Changeset.change(probed)
      |> McpRegistry.Repo.update!()
    end
  end
end
