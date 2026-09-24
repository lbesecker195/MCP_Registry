defmodule McpRegistry.Registry.Clients do
  @moduledoc """
  Ready-to-paste configuration for each MCP client, for one listing.

  `McpRegistry.Registry.Install` answers "what command runs this server".
  This module answers "where do I put that, and in what shape", which is a
  different question per client and the one people actually get wrong.

  The four shapes are not interchangeable, and a wrong one fails silently --
  the client starts, finds nothing, and says nothing:

    * Claude Desktop, Cursor and Windsurf read `mcpServers`.
    * VS Code reads `servers`, and ignores an `mcpServers` object entirely.
    * Zed reads `context_servers`.
    * Claude Code is configured from its CLI.

  Remote servers diverge again. Cursor and Zed take a bare `url`; VS Code
  wants `type` alongside it; Windsurf spells the same field `serverUrl`; and
  Claude Desktop has no remote form at all in its config file, so it goes
  through the `mcp-remote` stdio bridge.

  Values the reader has to supply are written as `<SCREAMING_SNAKE>`, which is
  what `McpRegistryWeb.CoreComponents.code_block/1` highlights. VS Code is the
  exception: it has a first-class prompt mechanism, so secrets there are
  declared in `inputs` and referenced as `${input:...}`, and the reader is
  prompted rather than editing the file.
  """
  alias McpRegistry.Registry.{Install, Server}

  @doc """
  Every client configuration for a listing, in the order they are offered.

  Each entry is a map of:

    * `:id` -- stable slug, used for the tab's DOM ids
    * `:label` -- the client's name
    * `:kind` -- `:cli` for a command to run, `:json` for a file to edit
    * `:accepts_secrets` -- whether `<PLACEHOLDER>` substitution applies. False
      for VS Code, whose secrets go through its own `inputs` prompt instead
    * `:path` -- where the config lives, or the scope for a CLI
    * `:path_windows` -- the Windows spelling of `:path`, when it differs
    * `:code` -- the snippet
    * `:note` -- a one-line caveat, or `nil`
    * `:docs_url` -- the vendor's own MCP documentation

  Returns `[]` for a listing with neither a package nor a remote endpoint,
  since there would be nothing to configure.
  """
  def configs(%Server{} = server) do
    if configurable?(server) do
      [
        claude_code(server),
        claude_desktop(server),
        cursor(server),
        vscode(server),
        zed(server),
        windsurf(server),
        cline(server),
        gemini(server),
        grok(server),
        chatgpt(server),
        claude_ai(server),
        langchain(server)
      ]
      |> Enum.reject(&is_nil/1)
    else
      []
    end
  end

  @doc """
  Just the client ids for a listing, without rendering six configurations.

  The sitemap needs to know which client pages exist for ten thousand
  listings. Calling `configs/1` for each would JSON-encode sixty thousand
  snippets to then throw them away.
  """
  def ids(%Server{} = server), do: server |> configs() |> Enum.map(& &1.id)

  defp configurable?(%Server{} = server) do
    Server.remote?(server) or Install.command(server) != nil
  end

  # --- Claude Code -----------------------------------------------------------

  defp claude_code(%Server{} = server) do
    short = Server.short_name(server)

    code =
      if Server.remote?(server) do
        "claude mcp add --transport #{http_kind(server)} #{short} #{server.remote_url}"
      else
        {cmd, args} = Install.command(server)
        "claude mcp add #{short}#{cli_env_flags(server)} -- #{cmd} #{Enum.join(args, " ")}"
      end

    %{
      id: "claude-code",
      label: "Claude Code",
      kind: :cli,
      accepts_secrets: true,
      path: "run in your project directory",
      path_windows: nil,
      code: code,
      note: "Adds it for this project only. Append --scope user to make it available everywhere.",
      docs_url: "https://docs.claude.com/en/docs/claude-code/mcp"
    }
  end

  defp cli_env_flags(%Server{env_vars: vars}), do: Enum.map_join(vars, "", &" -e #{&1}=<#{&1}>")

  # --- Claude Desktop --------------------------------------------------------

  # Claude Desktop's config file has no remote form: `type` and `url` are Claude
  # Code's, not Claude Desktop's. Remote servers run through the mcp-remote
  # bridge, which speaks stdio to the app and HTTP to the server.
  defp claude_desktop(%Server{} = server) do
    entry =
      if Server.remote?(server) do
        ordered([
          {"command", "npx"},
          {"args", ["-y", "mcp-remote", server.remote_url]}
        ])
      else
        stdio_entry(server)
      end

    %{
      id: "claude-desktop",
      label: "Claude Desktop",
      kind: :json,
      accepts_secrets: true,
      path: "~/Library/Application Support/Claude/claude_desktop_config.json",
      path_windows: "%APPDATA%\\Claude\\claude_desktop_config.json",
      code: wrap(server, "mcpServers", entry),
      note:
        if(Server.remote?(server),
          do:
            "Claude Desktop has no remote transport in its config file, so this bridges through mcp-remote. Restart the app after saving.",
          else:
            "Settings → Developer → Edit Config opens this file. Restart the app after saving."
        ),
      docs_url: "https://modelcontextprotocol.io/docs/develop/connect-local-servers"
    }
  end

  # --- Cursor ----------------------------------------------------------------

  defp cursor(%Server{} = server) do
    entry =
      if Server.remote?(server) do
        ordered([{"url", server.remote_url}])
      else
        stdio_entry(server, type: "stdio")
      end

    %{
      id: "cursor",
      label: "Cursor",
      kind: :json,
      accepts_secrets: true,
      path: "~/.cursor/mcp.json",
      path_windows: "%USERPROFILE%\\.cursor\\mcp.json",
      code: wrap(server, "mcpServers", entry),
      note:
        "Use .cursor/mcp.json in a project root instead to scope it to that project. Cursor merges both.",
      docs_url: "https://cursor.com/docs/mcp"
    }
  end

  # --- VS Code ---------------------------------------------------------------

  # VS Code is the odd one out twice over: the key is `servers`, not
  # `mcpServers`, and secrets belong in a sibling `inputs` array so the editor
  # prompts for them instead of the value sitting in a file.
  defp vscode(%Server{} = server) do
    short = Server.short_name(server)

    entry =
      if Server.remote?(server) do
        ordered([
          {"type", http_kind(server)},
          {"url", server.remote_url}
        ])
      else
        {cmd, args} = Install.command(server)

        [{"type", "stdio"}, {"command", cmd}, {"args", args}]
        |> then(fn pairs ->
          case server.env_vars do
            [] -> pairs
            vars -> pairs ++ [{"env", ordered(Enum.map(vars, &{&1, "${input:#{input_id(&1)}}"}))}]
          end
        end)
        |> ordered()
      end

    document =
      case {Server.remote?(server), server.env_vars} do
        {false, [_ | _] = vars} ->
          ordered([
            {"inputs", Enum.map(vars, &vscode_input/1)},
            {"servers", ordered([{short, entry}])}
          ])

        _ ->
          ordered([{"servers", ordered([{short, entry}])}])
      end

    %{
      id: "vscode",
      label: "VS Code",
      kind: :json,
      accepts_secrets: false,
      path: ".vscode/mcp.json",
      path_windows: nil,
      code: encode(document),
      note: vscode_note(server),
      docs_url: "https://code.visualstudio.com/docs/copilot/customization/mcp-servers"
    }
  end

  defp vscode_note(%Server{env_vars: [_ | _]} = server) do
    if Server.remote?(server) do
      vscode_default_note()
    else
      "VS Code prompts for each input the first time the server starts, so no secret is written to the file."
    end
  end

  defp vscode_note(_server), do: vscode_default_note()

  defp vscode_default_note do
    "Requires agent mode. MCP: Open User Configuration puts the same block in every workspace."
  end

  defp vscode_input(var) do
    ordered([
      {"type", "promptString"},
      {"id", input_id(var)},
      {"description", var},
      {"password", true}
    ])
  end

  defp input_id(var), do: var |> String.downcase() |> String.replace("_", "-")

  # --- Zed -------------------------------------------------------------------

  # Zed's settings enum is untagged: the variant is chosen by the shape of the
  # object, so `command` means stdio and `url` means remote. A `source` or
  # `type` key here is from an older Zed and is rejected now.
  defp zed(%Server{} = server) do
    entry =
      if Server.remote?(server) do
        ordered([{"url", server.remote_url}])
      else
        stdio_entry(server)
      end

    %{
      id: "zed",
      label: "Zed",
      kind: :json,
      accepts_secrets: true,
      path: "~/.config/zed/settings.json",
      path_windows: "%APPDATA%\\Zed\\settings.json",
      code: wrap(server, "context_servers", entry),
      note: "Merge this into your existing settings object — do not replace the file.",
      docs_url: "https://zed.dev/docs/ai/mcp"
    }
  end

  # --- Windsurf --------------------------------------------------------------

  defp windsurf(%Server{} = server) do
    entry =
      if Server.remote?(server) do
        ordered([{"serverUrl", server.remote_url}])
      else
        stdio_entry(server)
      end

    %{
      id: "windsurf",
      label: "Windsurf",
      kind: :json,
      accepts_secrets: true,
      path: "~/.codeium/windsurf/mcp_config.json",
      path_windows: "%USERPROFILE%\\.codeium\\windsurf\\mcp_config.json",
      code: wrap(server, "mcpServers", entry),
      note: "Global only — Windsurf has no per-project MCP config. Refresh Cascade after saving.",
      docs_url: "https://docs.devin.ai/desktop/cascade/mcp"
    }
  end

  # --- Cline -----------------------------------------------------------------

  # A VS Code extension, but it keeps its own file in the editor's
  # globalStorage rather than using .vscode/mcp.json, and it uses `mcpServers`
  # where VS Code itself uses `servers`.
  defp cline(%Server{} = server) do
    entry =
      if Server.remote?(server),
        do: ordered([{"url", server.remote_url}]),
        else: stdio_entry(server)

    %{
      id: "cline",
      label: "Cline",
      kind: :json,
      accepts_secrets: true,
      path:
        "~/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json",
      path_windows:
        "%APPDATA%\\Code\\User\\globalStorage\\saoudrizwan.claude-dev\\settings\\cline_mcp_settings.json",
      code: wrap(server, "mcpServers", entry),
      note: "Cline's MCP Servers pane edits this file for you if you would rather not find it.",
      docs_url: "https://docs.cline.bot/mcp/mcp-overview"
    }
  end

  # --- Gemini CLI --------------------------------------------------------------

  defp gemini(%Server{} = server) do
    entry =
      if Server.remote?(server) do
        ordered([{if(server.transport == "sse", do: "url", else: "httpUrl"), server.remote_url}])
      else
        stdio_entry(server)
      end

    %{
      id: "gemini",
      label: "Gemini CLI",
      kind: :json,
      accepts_secrets: true,
      path: "~/.gemini/settings.json",
      path_windows: "%USERPROFILE%\\.gemini\\settings.json",
      code: wrap(server, "mcpServers", entry),
      note:
        "Gemini expands $VAR and ${VAR} inside env values, so a secret can live in your shell rather than this file.",
      docs_url: "https://google-gemini.github.io/gemini-cli/docs/tools/mcp-server.html"
    }
  end

  # --- Grok --------------------------------------------------------------------

  # Grok Build reads Claude Code's .mcp.json and Claude Desktop's config as-is,
  # so the file it wants is one you may already have.
  defp grok(%Server{} = server) do
    entry =
      if Server.remote?(server) do
        ordered([{"type", http_kind(server)}, {"url", server.remote_url}])
      else
        stdio_entry(server, type: "stdio")
      end

    %{
      id: "grok",
      label: "Grok",
      kind: :json,
      accepts_secrets: true,
      path: ".mcp.json (in your project root)",
      path_windows: nil,
      code: wrap(server, "mcpServers", entry),
      note:
        "Grok Build reads Claude Code's .mcp.json and Claude Desktop's config unchanged, so a server you have already set up there needs nothing new. The Grok web app and X integration do not take custom servers.",
      docs_url: "https://docs.x.ai/developers/tools/remote-mcp"
    }
  end

  # --- ChatGPT and Claude.ai ---------------------------------------------------

  # Both take remote servers through a UI, not a file, and neither will run a
  # local package. A packaged listing genuinely cannot be installed in them,
  # and saying so is more useful than inventing a config.
  defp chatgpt(%Server{} = server) do
    if Server.remote?(server) do
      %{
        id: "chatgpt",
        label: "ChatGPT",
        kind: :ui,
        accepts_secrets: false,
        path: "Settings → Connectors → Advanced → Developer mode",
        path_windows: nil,
        code: server.remote_url,
        note:
          "Custom connectors are a paid-plan feature and take a remote URL only. ChatGPT cannot run a packaged server locally.",
        docs_url: "https://developers.openai.com/api/docs/mcp"
      }
    end
  end

  defp claude_ai(%Server{} = server) do
    if Server.remote?(server) do
      %{
        id: "claude-ai",
        label: "Claude.ai",
        kind: :ui,
        accepts_secrets: false,
        path: "Settings → Connectors → Add custom connector",
        path_windows: nil,
        code: server.remote_url,
        note:
          "Claude on the web takes a remote URL and completes OAuth in the browser. For a packaged server use Claude Desktop or Claude Code instead.",
        docs_url:
          "https://support.claude.com/en/articles/11175166-getting-started-with-custom-connectors-using-remote-mcp"
      }
    end
  end

  # --- LangChain ---------------------------------------------------------------

  # Not an application with a config file: a library you call. The snippet is
  # the install instruction.
  defp langchain(%Server{} = server) do
    short = Server.short_name(server)

    connection =
      if Server.remote?(server) do
        ~s(        "#{short}": {\n            "transport": "streamable_http",\n            "url": "#{server.remote_url}",\n        }\n)
      else
        case Install.command(server) do
          {cmd, args} ->
            args_literal = Enum.map_join(args, ", ", &~s("#{&1}"))

            ~s(        "#{short}": {\n            "transport": "stdio",\n            "command": "#{cmd}",\n            "args": [#{args_literal}],\n        }\n)

          nil ->
            nil
        end
      end

    if connection do
      %{
        id: "langchain",
        label: "LangChain",
        kind: :code,
        accepts_secrets: false,
        path: "pip install langchain-mcp-adapters",
        path_windows: nil,
        code: """
        from langchain_mcp_adapters.client import MultiServerMCPClient

        client = MultiServerMCPClient({
        #{String.trim_trailing(connection)}
        })

        tools = await client.get_tools()
        """,
        note: "get_tools() returns the server's tools as LangChain tools, ready for an agent.",
        docs_url: "https://github.com/langchain-ai/langchain-mcp-adapters"
      }
    end
  end

  # --- Shared ----------------------------------------------------------------

  defp stdio_entry(%Server{} = server, opts \\ []) do
    {cmd, args} = Install.command(server)

    [{"command", cmd}, {"args", args}]
    |> prepend_type(opts[:type])
    |> append_env(server)
    |> ordered()
  end

  defp prepend_type(pairs, nil), do: pairs
  defp prepend_type(pairs, type), do: [{"type", type} | pairs]

  defp append_env(pairs, %Server{env_vars: []}), do: pairs

  defp append_env(pairs, %Server{env_vars: vars}),
    do: pairs ++ [{"env", ordered(Enum.map(vars, &{&1, "<#{&1}>"}))}]

  defp wrap(%Server{} = server, key, entry) do
    encode(ordered([{key, ordered([{Server.short_name(server), entry}])}]))
  end

  defp http_kind(%Server{transport: "sse"}), do: "sse"
  defp http_kind(_), do: "http"

  defp ordered(pairs), do: Jason.OrderedObject.new(pairs)

  defp encode(document), do: Jason.encode!(document, pretty: true)
end
