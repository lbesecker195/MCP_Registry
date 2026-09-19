defmodule McpRegistryWeb.CoreComponents do
  @moduledoc """
  Core UI building blocks for MCP Harbor.

  Styling is plain Tailwind CSS, loaded from the CDN in `root.html.heex`. There
  is no component framework underneath: every class here is a Tailwind utility
  resolving against the design tokens declared in `assets/css/app.css` and
  re-exported to Tailwind in the layout's `@theme inline` block.

  The palette is referenced only through those tokens -- `bg-canvas`,
  `bg-surface`, `bg-sunken`, `text-ink`, `text-dim`, `border-rule`,
  `bg-brand`, `text-accent` -- never as raw Tailwind colours. That indirection
  is what lets the light and dark themes stay in step: the utility emits
  `var(--ink)`, and flipping `data-theme` re-resolves it.

    * [Tailwind CSS](https://tailwindcss.com) - the utility vocabulary.
    * [Heroicons](https://heroicons.com) - see `icon/1`. Paths are inlined at
      compile time from the `heroicons` dependency, because the Tailwind plugin
      that used to generate `hero-*` mask classes cannot run in the browser
      build.
    * [Phoenix.Component](https://phoenix-live-view.hexdocs.pm/Phoenix.Component.html) -
      the component system, which defines `<.link>` and `<.form>`.
  """
  use Phoenix.Component
  use Gettext, backend: McpRegistryWeb.Gettext

  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices as a dismissible toast in the top-right corner.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash
        id="welcome-back"
        kind={:info}
        phx-mounted={show("#welcome-back") |> JS.remove_attribute("hidden")}
        hidden
      >
        Welcome Back!
      </.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="fixed top-4 right-4 z-50 w-[min(24rem,calc(100vw-2rem))] cursor-pointer"
      {@rest}
    >
      <div class={[
        "rise flex items-start gap-3 rounded-box border p-4 shadow-lg backdrop-blur-sm",
        @kind == :info && "border-brand/30 bg-surface text-ink",
        @kind == :error && "border-danger/40 bg-surface text-ink"
      ]}>
        <.icon
          :if={@kind == :info}
          name="hero-information-circle"
          class="size-5 shrink-0 text-brand"
        />
        <.icon
          :if={@kind == :error}
          name="hero-exclamation-circle"
          class="size-5 shrink-0 text-danger"
        />
        <div class="min-w-0 flex-1 text-sm">
          <p :if={@title} class="font-semibold">{@title}</p>
          <p class="text-pretty break-words">{msg}</p>
        </div>
        <button
          type="button"
          class="shrink-0 text-dim transition-colors hover:text-ink"
          aria-label={gettext("close")}
        >
          <.icon name="hero-x-mark" class="size-4" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a button, or a link styled as one when given `href`/`navigate`/`patch`.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button navigate={~p"/"}>Home</.button>
  """
  attr :rest, :global,
    include: ~w(href navigate patch method download name value disabled type rel target)

  attr :class, :any, default: nil
  attr :variant, :string, values: ~w(primary soft ghost), default: "soft"
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    variants = %{
      "primary" =>
        "bg-brand text-brand-ink shadow-sm hover:shadow-md hover:brightness-110 active:brightness-95",
      "soft" => "border border-rule bg-surface text-ink hover:border-rule-strong hover:bg-sunken",
      "ghost" => "text-dim hover:bg-surface hover:text-ink"
    }

    assigns =
      assign(assigns, :computed_class, [
        "inline-flex items-center justify-center gap-2 rounded-field px-4 py-2",
        "text-sm font-medium transition-all duration-200",
        "active:scale-[0.98] disabled:pointer-events-none disabled:opacity-50",
        "phx-submit-loading:pointer-events-none phx-submit-loading:opacity-70",
        Map.fetch!(variants, assigns.variant),
        assigns.class
      ])

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@computed_class} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@computed_class} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as radio, are best
  written directly in your templates.

  ## Examples

  ```heex
  <.input field={@form[:email]} type="email" />
  <.input name="my-input" errors={["oh no!"]} />
  ```

  ## Select type

  When using `type="select"`, you must pass the `options` and optionally
  a `value` to mark which option should be preselected.

  ```heex
  <.input field={@form[:user_type]} type="select" options={["Admin": "admin", "User": "user"]} />
  ```

  For more information on what kind of data can be passed to `options` see
  [`options_for_select`](https://phoenix-html.hexdocs.pm/Phoenix.HTML.Form.html#options_for_select/2).
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any
  attr :hint, :string, default: nil, doc: "optional helper text shown under the control"

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week hidden)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :any, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :any, default: nil, doc: "the input error class to use over defaults"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div>
      <label for={@id} class="flex cursor-pointer items-center gap-2.5 text-sm">
        <input
          type="hidden"
          name={@name}
          value="false"
          disabled={@rest[:disabled]}
          form={@rest[:form]}
        />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class={
            @class ||
              "size-4 shrink-0 cursor-pointer rounded-[0.25rem] border border-rule-strong bg-surface accent-brand transition-colors"
          }
          {@rest}
        />
        <span>{@label}</span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div>
      <.field_label :if={@label} for={@id}>{@label}</.field_label>
      <select
        id={@id}
        name={@name}
        class={[
          @class || field_classes(),
          "cursor-pointer",
          @errors != [] && (@error_class || "border-danger")
        ]}
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value="">{@prompt}</option>
        {Phoenix.HTML.Form.options_for_select(@options, @value)}
      </select>
      <.hint :if={@hint}>{@hint}</.hint>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div>
      <.field_label :if={@label} for={@id}>{@label}</.field_label>
      <textarea
        id={@id}
        name={@name}
        rows={@rest[:rows] || 4}
        class={[
          @class || field_classes(),
          "resize-y",
          @errors != [] && (@error_class || "border-danger")
        ]}
        {@rest}
      >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      <.hint :if={@hint}>{@hint}</.hint>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div>
      <.field_label :if={@label} for={@id}>{@label}</.field_label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          @class || field_classes(),
          @errors != [] && (@error_class || "border-danger")
        ]}
        {@rest}
      />
      <.hint :if={@hint}>{@hint}</.hint>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # One definition of what a form control looks like, shared by every input
  # type so text, select and textarea line up on the same grid.
  defp field_classes do
    [
      "w-full rounded-field border border-rule bg-surface px-3 py-2",
      "text-sm text-ink outline-none transition-colors",
      "placeholder:text-dim hover:border-rule-strong focus:border-brand"
    ]
  end

  attr :for, :string, default: nil
  slot :inner_block, required: true

  defp field_label(assigns) do
    ~H"""
    <label
      for={@for}
      class="mb-1.5 block font-mono text-[11px] font-medium tracking-wide text-dim uppercase"
    >
      {render_slot(@inner_block)}
    </label>
    """
  end

  slot :inner_block, required: true

  defp hint(assigns) do
    ~H"""
    <p class="mt-1.5 text-xs text-dim">{render_slot(@inner_block)}</p>
    """
  end

  # Helper used by inputs to generate form errors
  slot :inner_block, required: true

  defp error(assigns) do
    ~H"""
    <p class="mt-1.5 flex items-center gap-1.5 text-xs text-danger">
      <.icon name="hero-exclamation-circle" class="size-4 shrink-0" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a page header with an optional subtitle and actions.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex flex-wrap items-end justify-between gap-6", "pb-2"]}>
      <div class="max-w-2xl space-y-2">
        <h1 class="text-2xl font-semibold tracking-tight text-balance sm:text-3xl">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="text-sm text-pretty text-dim">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div :if={@actions != []} class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a definition list of metadata, one hairline-separated row per item.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <dl class="rule-list overflow-hidden rounded-box border border-rule">
      <div :for={item <- @item} class="grid gap-1 px-4 py-3 even:bg-surface/50">
        <dt class="font-mono text-[11px] tracking-wide text-dim uppercase">{item.title}</dt>
        <dd class="text-sm break-words">{render_slot(item)}</dd>
      </div>
    </dl>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com) as inline SVG.

  The name is the heroicon's own, prefixed with `hero-`. A `-micro` suffix
  selects the 16px solid set; everything else resolves to the 24px outline set.
  Paths are compiled in from the `heroicons` dependency, so the icon ships with
  the markup and needs no stylesheet -- which is what the Tailwind CDN build
  requires, since it cannot run the plugin that used to generate mask classes.

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    {view_box, kind, body} = icon_data(assigns.name)

    assigns =
      assign(assigns, view_box: view_box, kind: kind, body: Phoenix.HTML.raw(body))

    ~H"""
    <svg
      viewBox={@view_box}
      class={["inline-block shrink-0", @class]}
      fill={if @kind == :solid, do: "currentColor", else: "none"}
      stroke={if @kind == :outline, do: "currentColor"}
      stroke-width={if @kind == :outline, do: "1.5"}
      aria-hidden="true"
    >{@body}</svg>
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(McpRegistryWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(McpRegistryWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end

  @doc """
  A runnable command with a shell-prompt gutter and a copy button.

  The `$` is drawn by CSS in `::before` and is unselectable, so copying the
  block -- by button or by hand -- yields a command that pastes and runs.

  ## Examples

      <.copy_command id="agent-install" command="claude mcp add ..." />
  """
  attr :id, :string, required: true
  attr :command, :string, required: true
  attr :label, :string, default: nil, doc: "optional caption shown above the command"
  attr :class, :string, default: nil

  def copy_command(assigns) do
    ~H"""
    <div id={@id} class={["group relative", @class]} phx-hook=".CopyCommand">
      <p :if={@label} class="mb-1.5 font-mono text-[11px] tracking-wide text-dim uppercase">
        {@label}
      </p>
      <pre class="cmd overflow-x-auto rounded-box border border-rule bg-sunken py-3 pr-16 font-mono text-xs leading-relaxed"><code>{@command}</code></pre>
      <button
        type="button"
        data-command={@command}
        aria-label={"Copy command: #{@command}"}
        class={[
          "absolute right-2 rounded-field border border-rule bg-surface px-2 py-1",
          "font-mono text-[11px] text-dim transition-all duration-200",
          "hover:border-rule-strong hover:text-ink",
          "opacity-0 group-hover:opacity-100 focus-visible:opacity-100",
          if(@label, do: "top-8", else: "top-2")
        ]}
      >
        copy
      </button>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".CopyCommand">
        export default {
          mounted() {
            const button = this.el.querySelector("button[data-command]")
            if (!button) return

            const original = button.textContent
            let revert

            button.addEventListener("click", async () => {
              try {
                await navigator.clipboard.writeText(button.dataset.command)
                button.textContent = "copied"
              } catch {
                // Clipboard can be blocked by permissions or an insecure origin.
                // Select the text instead so the user can still copy by hand.
                const code = this.el.querySelector("code")
                if (code) {
                  const range = document.createRange()
                  range.selectNodeContents(code)
                  const selection = window.getSelection()
                  selection.removeAllRanges()
                  selection.addRange(range)
                }
                button.textContent = "select + copy"
              }
              button.classList.add("opacity-100", "text-ink")
              clearTimeout(revert)
              revert = setTimeout(() => {
                button.textContent = original
                button.classList.remove("opacity-100", "text-ink")
              }, 1600)
            })
          },
          destroyed() {
            // nothing retained beyond the listener, which goes with the element
          }
        }
      </script>
    </div>
    """
  end

  @doc """
  A block of code or configuration, with a copy button that always shows.

  Unlike `copy_command/1` this is for multi-line configuration rather than a
  single shell command: there is no `$` gutter, the copy button is opaque, and
  placeholders are highlighted.

  A placeholder is any `<SCREAMING_SNAKE>` token — the shape
  `McpRegistry.Registry.Install` emits for a value the reader has to supply.
  They are wrapped in `.placeholder` so the one thing that must be edited
  before the snippet works is the one thing that catches the eye.

  ## Examples

      <.code_block id="claude-desktop" code={@config.code} copy_label="Copy config" />
  """
  attr :id, :string, required: true
  attr :code, :string, required: true
  attr :copy_label, :string, default: "Copy"
  attr :class, :any, default: nil
  attr :max_height, :string, default: nil, doc: "e.g. \"max-h-96\" to cap a long block"

  def code_block(assigns) do
    assigns = assign(assigns, :segments, highlight_placeholders(assigns.code))

    ~H"""
    <div id={@id} class={["group/code relative", @class]} phx-hook=".CopyCommand">
      <pre class={[
        "scroll-thin overflow-x-auto rounded-box border border-rule bg-sunken",
        "p-4 pr-24 font-mono text-xs leading-relaxed",
        @max_height && "#{@max_height} overflow-y-auto"
      ]}><code><span :for={{kind, text} <- @segments} class={if kind == :placeholder, do: "placeholder"}>{text}</span></code></pre>
      <button
        type="button"
        data-command={@code}
        aria-label={"Copy: #{@copy_label}"}
        class={[
          "absolute top-3 right-3 inline-flex items-center gap-1.5 rounded-field",
          "bg-brand px-2.5 py-1.5 font-mono text-[11px] font-semibold text-brand-ink",
          "shadow-sm transition-all duration-200",
          "hover:brightness-110 active:scale-[0.98]",
          "opacity-90 group-hover/code:opacity-100"
        ]}
      >
        {@copy_label}
      </button>
    </div>
    """
  end

  # Splits a snippet into `{:text, _}` and `{:placeholder, _}` runs. Keeping
  # this out of the template means the raw string still goes to the clipboard
  # untouched -- the highlight is presentation only.
  defp highlight_placeholders(code) do
    Regex.split(~r/<[A-Z][A-Z0-9_]*>/, code, include_captures: true, trim: true)
    |> Enum.map(fn part ->
      if Regex.match?(~r/^<[A-Z][A-Z0-9_]*>$/, part),
        do: {:placeholder, part},
        else: {:text, part}
    end)
  end

  @doc """
  A small status pill.

  `dot` adds a filled dot before the label, for states that are worth reading
  as live rather than as a category.

  ## Examples

      <.badge tone="success" dot>Verified official</.badge>
      <.badge tone="warning">Mutating</.badge>
  """
  attr :tone, :string,
    values: ~w(neutral brand success warning danger accent),
    default: "neutral"

  attr :dot, :boolean, default: false
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def badge(assigns) do
    tones = %{
      "neutral" => {"border-rule bg-surface text-dim", "bg-dim"},
      "brand" => {"border-brand/30 bg-brand/10 text-brand", "bg-brand"},
      "success" => {"border-success/30 bg-success/10 text-success", "bg-success"},
      "warning" => {"border-warning/30 bg-warning/10 text-warning", "bg-warning"},
      "danger" => {"border-danger/30 bg-danger/10 text-danger", "bg-danger"},
      "accent" => {"border-accent/30 bg-accent/10 text-accent", "bg-accent"}
    }

    {pill, dot} = Map.fetch!(tones, assigns.tone)
    assigns = assign(assigns, pill_class: pill, dot_class: dot)

    ~H"""
    <span
      class={[
        "inline-flex items-center gap-1.5 rounded-full border px-2 py-0.5",
        "font-mono text-[11px] font-medium whitespace-nowrap",
        @pill_class,
        @class
      ]}
      {@rest}
    >
      <span :if={@dot} class={["size-1.5 rounded-full", @dot_class]} aria-hidden="true"></span>
      {render_slot(@inner_block)}
    </span>
    """
  end

  @doc """
  A `key:value` fact, set as one monospace chip.

  Used under a listing's title to state transport, runtime and licence at a
  glance, in the same shape the identifier is written in.

  ## Examples

      <.meta_chip key="transport" value="stdio" tone="brand" />
  """
  attr :key, :string, required: true
  attr :value, :any, required: true
  attr :tone, :string, values: ~w(neutral brand accent), default: "neutral"

  def meta_chip(assigns) do
    tones = %{
      "neutral" => "border-rule bg-surface text-dim",
      "brand" => "border-brand/30 bg-brand/10 text-brand",
      "accent" => "border-accent/30 bg-accent/10 text-accent"
    }

    assigns = assign(assigns, :tone_class, Map.fetch!(tones, assigns.tone))

    ~H"""
    <span class={[
      "inline-flex items-center rounded-field border px-2 py-0.5 font-mono text-[11px]",
      @tone_class
    ]}>
      <span class="opacity-70">{@key}:</span>{@value}
    </span>
    """
  end

  @doc """
  The identity tile for a listing: two initials on a hue derived from the name.

  The hue is a hash of the full reverse-DNS name, so a given server draws the
  same tile everywhere it appears and a page of results is scannable by colour
  before it is readable by name. Lightness and chroma are fixed in
  `.monogram`, so contrast does not drift between hues.

  ## Examples

      <.monogram name={@server.name} size="size-12" />
  """
  attr :name, :string, required: true
  attr :size, :string, default: "size-10"
  attr :class, :any, default: nil

  def monogram(assigns) do
    assigns =
      assign(assigns,
        initials: monogram_initials(assigns.name),
        hue: monogram_hue(assigns.name)
      )

    ~H"""
    <span
      class={[
        "monogram inline-flex shrink-0 items-center justify-center rounded-box border",
        "font-mono font-bold tracking-tight select-none",
        @size,
        @class
      ]}
      style={"--mono-h: #{@hue}"}
      aria-hidden="true"
    >
      {@initials}
    </span>
    """
  end

  # "io.github.github/github-mcp-server" -> "GI". Generic words are dropped
  # first, because almost every listing here ends in some arrangement of
  # "mcp server" and initials taken from those would all collide.
  @monogram_noise ~w(mcp server servers service api tool tools official)

  defp monogram_initials(name) when is_binary(name) do
    words =
      name
      |> String.split("/")
      |> List.last()
      |> String.split(~r/[^a-zA-Z0-9]+/, trim: true)
      |> Enum.reject(&(String.downcase(&1) in @monogram_noise))

    case words do
      [] -> "MC"
      [one] -> one |> String.slice(0, 2) |> String.upcase()
      [a, b | _] -> String.upcase(String.first(a) <> String.first(b))
    end
  end

  defp monogram_initials(_), do: "MC"

  # :erlang.phash2 is stable across runs and nodes, which matters: the tile has
  # to be the same colour in the catalogue and on the detail page.
  defp monogram_hue(name) when is_binary(name), do: rem(:erlang.phash2(name), 360)
  defp monogram_hue(_), do: 250

  @doc """
  A titled panel: the site's standard box for a self-contained block of facts.

  This is the sidebar unit on the server detail page, and the same shape any
  page should reach for when it needs a bordered group with a label.

  ## Examples

      <.panel title="Security and token scopes" icon="hero-shield-check">
        …
      </.panel>
  """
  attr :title, :string, required: true
  attr :icon, :string, default: nil
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def panel(assigns) do
    ~H"""
    <section class={["space-y-3 rounded-box border border-rule bg-surface/30 p-4", @class]}>
      <h2 class="flex items-center gap-2 font-mono text-[11px] tracking-wide text-dim uppercase">
        <.icon :if={@icon} name={@icon} class="size-3.5 text-brand" />
        {@title}
      </h2>
      {render_slot(@inner_block)}
    </section>
    """
  end

  @doc """
  One key/value line inside a `panel/1`, hairline-separated from the next.

  ## Examples

      <.spec_row label="Transport" value="stdio" />
  """
  attr :label, :string, required: true
  attr :value, :any, default: nil
  attr :tone, :string, values: ~w(default brand success dim), default: "default"
  slot :inner_block

  def spec_row(assigns) do
    tones = %{
      "default" => "text-ink",
      "brand" => "text-brand",
      "success" => "text-success",
      "dim" => "text-dim"
    }

    assigns = assign(assigns, :value_class, Map.fetch!(tones, assigns.tone))

    ~H"""
    <div class="flex items-baseline justify-between gap-3 border-b border-rule py-1.5 text-xs last:border-0">
      <span class="shrink-0 text-dim">{@label}</span>
      <span class={["min-w-0 truncate text-right font-mono", @value_class]}>
        {if @inner_block == [], do: @value, else: render_slot(@inner_block)}
      </span>
    </div>
    """
  end

  @doc """
  A segmented control: one choice from a small set, as inset pills.

  Each option is `%{id, label}`. Clicking pushes `event` with `phx-value-<param>`
  set to the option's id, so the caller owns the state.

  ## Examples

      <.segmented options={@clients} selected={@selected_client} event="select_client" param="client" />
  """
  attr :options, :list, required: true
  attr :selected, :string, required: true
  attr :event, :string, required: true
  attr :param, :string, default: "value"
  attr :label, :string, default: nil, doc: "accessible name for the group"

  def segmented(assigns) do
    ~H"""
    <div
      class="flex flex-wrap gap-0.5 rounded-field border border-rule bg-canvas p-0.5"
      role="group"
      aria-label={@label}
    >
      <button
        :for={option <- @options}
        type="button"
        phx-click={@event}
        phx-value-value={if @param == "value", do: option.id}
        phx-value-client={if @param == "client", do: option.id}
        aria-pressed={to_string(@selected == option.id)}
        class={[
          "cursor-pointer rounded-[0.3125rem] px-3 py-1 font-mono text-xs transition-all duration-200",
          if(@selected == option.id,
            do: "bg-surface text-ink shadow-sm",
            else: "text-dim hover:text-ink"
          )
        ]}
      >
        {option.label}
      </button>
    </div>
    """
  end

  @doc """
  An underlined tab in a tab bar. The caller owns which one is current.

  ## Examples

      <.tab_button tab="tools" current={@active_tab} event="select_tab">Tools</.tab_button>
  """
  attr :tab, :string, required: true
  attr :current, :string, required: true
  attr :event, :string, required: true
  slot :inner_block, required: true

  def tab_button(assigns) do
    assigns = assign(assigns, :active?, assigns.tab == assigns.current)

    ~H"""
    <button
      type="button"
      phx-click={@event}
      phx-value-tab={@tab}
      aria-current={@active? && "page"}
      class={[
        "-mb-px cursor-pointer border-b-2 pb-2 text-sm font-medium whitespace-nowrap transition-colors",
        if(@active?,
          do: "border-brand text-brand",
          else: "border-transparent text-dim hover:text-ink"
        )
      ]}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  # --- Heroicon path data ----------------------------------------------------
  # Generated from deps/heroicons/optimized. `-micro` names come from 16/solid,
  # the rest from 24/outline. To add an icon, copy the <svg> body across and
  # keep the list alphabetical.

  defp icon_data("hero-adjustments-horizontal"),
    do:
      {"0 0 24 24", :outline,
       ~S|<path stroke-linecap="round" stroke-linejoin="round" d="M10.5 6h9.75M10.5 6a1.5 1.5 0 1 1-3 0m3 0a1.5 1.5 0 1 0-3 0M3.75 6H7.5m3 12h9.75m-9.75 0a1.5 1.5 0 0 1-3 0m3 0a1.5 1.5 0 0 0-3 0m-3.75 0H7.5m9-6h3.75m-3.75 0a1.5 1.5 0 0 1-3 0m3 0a1.5 1.5 0 0 0-3 0m-9.75 0h9.75"/>|}

  defp icon_data("hero-arrow-left-micro"),
    do:
      {"0 0 16 16", :solid,
       ~S|<path fill-rule="evenodd" d="M14 8a.75.75 0 0 1-.75.75H4.56l3.22 3.22a.75.75 0 1 1-1.06 1.06l-4.5-4.5a.75.75 0 0 1 0-1.06l4.5-4.5a.75.75 0 0 1 1.06 1.06L4.56 7.25h8.69A.75.75 0 0 1 14 8Z" clip-rule="evenodd"/>|}

  defp icon_data("hero-arrow-long-right"),
    do:
      {"0 0 24 24", :outline,
       ~S|<path stroke-linecap="round" stroke-linejoin="round" d="M17.25 8.25 21 12m0 0-3.75 3.75M21 12H3"/>|}

  defp icon_data("hero-arrow-path"),
    do:
      {"0 0 24 24", :outline,
       ~S|<path stroke-linecap="round" stroke-linejoin="round" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0 3.181 3.183a8.25 8.25 0 0 0 13.803-3.7M4.031 9.865a8.25 8.25 0 0 1 13.803-3.7l3.181 3.182m0-4.991v4.99"/>|}

  defp icon_data("hero-arrow-right"),
    do:
      {"0 0 24 24", :outline,
       ~S|<path stroke-linecap="round" stroke-linejoin="round" d="M13.5 4.5 21 12m0 0-7.5 7.5M21 12H3"/>|}

  defp icon_data("hero-arrow-right-micro"),
    do:
      {"0 0 16 16", :solid,
       ~S|<path fill-rule="evenodd" d="M2 8a.75.75 0 0 1 .75-.75h8.69L8.22 4.03a.75.75 0 0 1 1.06-1.06l4.5 4.5a.75.75 0 0 1 0 1.06l-4.5 4.5a.75.75 0 0 1-1.06-1.06l3.22-3.22H2.75A.75.75 0 0 1 2 8Z" clip-rule="evenodd"/>|}

  defp icon_data("hero-arrow-top-right-on-square"),
    do:
      {"0 0 24 24", :outline,
       ~S|<path stroke-linecap="round" stroke-linejoin="round" d="M13.5 6H5.25A2.25 2.25 0 0 0 3 8.25v10.5A2.25 2.25 0 0 0 5.25 21h10.5A2.25 2.25 0 0 0 18 18.75V10.5m-10.5 6L21 3m0 0h-5.25M21 3v5.25"/>|}

  defp icon_data("hero-arrow-up-right-micro"),
    do:
      {"0 0 16 16", :solid,
       ~S|<path fill-rule="evenodd" d="M4.22 11.78a.75.75 0 0 1 0-1.06L9.44 5.5H5.75a.75.75 0 0 1 0-1.5h5.5a.75.75 0 0 1 .75.75v5.5a.75.75 0 0 1-1.5 0V6.56l-5.22 5.22a.75.75 0 0 1-1.06 0Z" clip-rule="evenodd"/>|}

  defp icon_data("hero-bolt"),
    do:
      {"0 0 24 24", :outline,
       ~S|<path stroke-linecap="round" stroke-linejoin="round" d="m3.75 13.5 10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75Z"/>|}

  defp icon_data("hero-book-open"),
    do:
      {"0 0 24 24", :outline,
       ~S|<path stroke-linecap="round" stroke-linejoin="round" d="M12 6.042A8.967 8.967 0 0 0 6 3.75c-1.052 0-2.062.18-3 .512v14.25A8.987 8.987 0 0 1 6 18c2.305 0 4.408.867 6 2.292m0-14.25a8.966 8.966 0 0 1 6-2.292c1.052 0 2.062.18 3 .512v14.25A8.987 8.987 0 0 0 18 18a8.967 8.967 0 0 0-6 2.292m0-14.25v14.25"/>|}

  defp icon_data("hero-check-badge"),
    do:
      {"0 0 24 24", :outline,
       ~S|<path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75 11.25 15 15 9.75M21 12c0 1.268-.63 2.39-1.593 3.068a3.745 3.745 0 0 1-1.043 3.296 3.745 3.745 0 0 1-3.296 1.043A3.745 3.745 0 0 1 12 21c-1.268 0-2.39-.63-3.068-1.593a3.746 3.746 0 0 1-3.296-1.043 3.745 3.745 0 0 1-1.043-3.296A3.745 3.745 0 0 1 3 12c0-1.268.63-2.39 1.593-3.068a3.745 3.745 0 0 1 1.043-3.296 3.746 3.746 0 0 1 3.296-1.043A3.746 3.746 0 0 1 12 3c1.268 0 2.39.63 3.068 1.593a3.746 3.746 0 0 1 3.296 1.043 3.746 3.746 0 0 1 1.043 3.296A3.745 3.745 0 0 1 21 12Z"/>|}

  defp icon_data("hero-check-circle"),
    do:
      {"0 0 24 24", :outline,
       ~S|<path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"/>|}

  defp icon_data("hero-check-micro"),
    do:
      {"0 0 16 16", :solid,
       ~S|<path fill-rule="evenodd" d="M12.416 3.376a.75.75 0 0 1 .208 1.04l-5 7.5a.75.75 0 0 1-1.154.114l-3-3a.75.75 0 0 1 1.06-1.06l2.353 2.353 4.493-6.74a.75.75 0 0 1 1.04-.207Z" clip-rule="evenodd"/>|}

  defp icon_data("hero-chevron-down-micro"),
    do:
      {"0 0 16 16", :solid,
       ~S|<path fill-rule="evenodd" d="M4.22 6.22a.75.75 0 0 1 1.06 0L8 8.94l2.72-2.72a.75.75 0 1 1 1.06 1.06l-3.25 3.25a.75.75 0 0 1-1.06 0L4.22 7.28a.75.75 0 0 1 0-1.06Z" clip-rule="evenodd"/>|}

  defp icon_data("hero-chevron-right-micro"),
    do:
      {"0 0 16 16", :solid,
       ~S|<path fill-rule="evenodd" d="M6.22 4.22a.75.75 0 0 1 1.06 0l3.25 3.25a.75.75 0 0 1 0 1.06l-3.25 3.25a.75.75 0 0 1-1.06-1.06L8.94 8 6.22 5.28a.75.75 0 0 1 0-1.06Z" clip-rule="evenodd"/>|}

  defp icon_data("hero-clock"),
    do:
      {"0 0 24 24", :outline,
       ~S|<path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"/>|}

  defp icon_data("hero-code-bracket"),
    do:
      {"0 0 24 24", :outline,
       ~S|<path stroke-linecap="round" stroke-linejoin="round" d="M17.25 6.75 22.5 12l-5.25 5.25m-10.5 0L1.5 12l5.25-5.25m7.5-3-4.5 16.5"/>|}

  defp icon_data("hero-command-line"),
    do:
      {"0 0 24 24", :outline,
       ~S|<path stroke-linecap="round" stroke-linejoin="round" d="m6.75 7.5 3 2.25-3 2.25m4.5 0h3m-9 8.25h13.5A2.25 2.25 0 0 0 21 18V6a2.25 2.25 0 0 0-2.25-2.25H5.25A2.25 2.25 0 0 0 3 6v12a2.25 2.25 0 0 0 2.25 2.25Z"/>|}

  defp icon_data("hero-computer-desktop-micro"),
    do:
      {"0 0 16 16", :solid,
       ~S|<path fill-rule="evenodd" d="M2 4.25A2.25 2.25 0 0 1 4.25 2h7.5A2.25 2.25 0 0 1 14 4.25v5.5A2.25 2.25 0 0 1 11.75 12h-1.312c.1.128.21.248.328.36a.75.75 0 0 1 .234.545v.345a.75.75 0 0 1-.75.75h-4.5a.75.75 0 0 1-.75-.75v-.345a.75.75 0 0 1 .234-.545c.118-.111.228-.232.328-.36H4.25A2.25 2.25 0 0 1 2 9.75v-5.5Zm2.25-.75a.75.75 0 0 0-.75.75v4.5c0 .414.336.75.75.75h7.5a.75.75 0 0 0 .75-.75v-4.5a.75.75 0 0 0-.75-.75h-7.5Z" clip-rule="evenodd"/>|}

  defp icon_data("hero-cpu-chip"),
    do:
      {"0 0 24 24", :outline,
       ~S|<path stroke-linecap="round" stroke-linejoin="round" d="M8.25 3v1.5M4.5 8.25H3m18 0h-1.5M4.5 12H3m18 0h-1.5m-15 3.75H3m18 0h-1.5M8.25 19.5V21M12 3v1.5m0 15V21m3.75-18v1.5m0 15V21m-9-1.5h10.5a2.25 2.25 0 0 0 2.25-2.25V6.75a2.25 2.25 0 0 0-2.25-2.25H6.75A2.25 2.25 0 0 0 4.5 6.75v10.5a2.25 2.25 0 0 0 2.25 2.25Zm.75-12h9v9h-9v-9Z"/>|}

  defp icon_data("hero-cube-transparent"),
    do:
      {"0 0 24 24", :outline,
       ~S|<path stroke-linecap="round" stroke-linejoin="round" d="m21 7.5-2.25-1.313M21 7.5v2.25m0-2.25-2.25 1.313M3 7.5l2.25-1.313M3 7.5l2.25 1.313M3 7.5v2.25m9 3 2.25-1.313M12 12.75l-2.25-1.313M12 12.75V15m0 6.75 2.25-1.313M12 21.75V19.5m0 2.25-2.25-1.313m0-16.875L12 2.25l2.25 1.313M21 14.25v2.25l-2.25 1.313m-13.5 0L3 16.5v-2.25"/>|}

  defp icon_data("hero-envelope"),
    do:
      {"0 0 24 24", :outline,
       ~S|<path stroke-linecap="round" stroke-linejoin="round" d="M21.75 6.75v10.5a2.25 2.25 0 0 1-2.25 2.25h-15a2.25 2.25 0 0 1-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0 0 19.5 4.5h-15a2.25 2.25 0 0 0-2.25 2.25m19.5 0v.243a2.25 2.25 0 0 1-1.07 1.916l-7.5 4.615a2.25 2.25 0 0 1-2.36 0L3.32 8.91a2.25 2.25 0 0 1-1.07-1.916V6.75"/>|}

  defp icon_data("hero-exclamation-circle"),
    do:
      {"0 0 24 24", :outline,
       ~S|<path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9 3.75h.008v.008H12v-.008Z"/>|}

  defp icon_data("hero-funnel"),
    do:
      {"0 0 24 24", :outline,
       ~S|<path stroke-linecap="round" stroke-linejoin="round" d="M12 3c2.755 0 5.455.232 8.083.678.533.09.917.556.917 1.096v1.044a2.25 2.25 0 0 1-.659 1.591l-5.432 5.432a2.25 2.25 0 0 0-.659 1.591v2.927a2.25 2.25 0 0 1-1.244 2.013L9.75 21v-6.568a2.25 2.25 0 0 0-.659-1.591L3.659 7.409A2.25 2.25 0 0 1 3 5.818V4.774c0-.54.384-1.006.917-1.096A48.32 48.32 0 0 1 12 3Z"/>|}

  defp icon_data("hero-globe-alt"),
    do:
      {"0 0 24 24", :outline,
       ~S|<path stroke-linecap="round" stroke-linejoin="round" d="M12 21a9.004 9.004 0 0 0 8.716-6.747M12 21a9.004 9.004 0 0 1-8.716-6.747M12 21c2.485 0 4.5-4.03 4.5-9S14.485 3 12 3m0 18c-2.485 0-4.5-4.03-4.5-9S9.515 3 12 3m0 0a8.997 8.997 0 0 1 7.843 4.582M12 3a8.997 8.997 0 0 0-7.843 4.582m15.686 0A11.953 11.953 0 0 1 12 10.5c-2.998 0-5.74-1.1-7.843-2.918m15.686 0A8.959 8.959 0 0 1 21 12c0 .778-.099 1.533-.284 2.253m0 0A17.919 17.919 0 0 1 12 16.5c-3.162 0-6.133-.815-8.716-2.247m0 0A9.015 9.015 0 0 1 3 12c0-1.605.42-3.113 1.157-4.418"/>|}

  defp icon_data("hero-information-circle"),
    do:
      {"0 0 24 24", :outline,
       ~S|<path stroke-linecap="round" stroke-linejoin="round" d="m11.25 11.25.041-.02a.75.75 0 0 1 1.063.852l-.708 2.836a.75.75 0 0 0 1.063.853l.041-.021M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9-3.75h.008v.008H12V8.25Z"/>|}

  defp icon_data("hero-link"),
    do:
      {"0 0 24 24", :outline,
       ~S|<path stroke-linecap="round" stroke-linejoin="round" d="M13.19 8.688a4.5 4.5 0 0 1 1.242 7.244l-4.5 4.5a4.5 4.5 0 0 1-6.364-6.364l1.757-1.757m13.35-.622 1.757-1.757a4.5 4.5 0 0 0-6.364-6.364l-4.5 4.5a4.5 4.5 0 0 0 1.242 7.244"/>|}

  defp icon_data("hero-magnifying-glass"),
    do:
      {"0 0 24 24", :outline,
       ~S|<path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z"/>|}

  defp icon_data("hero-moon-micro"),
    do:
      {"0 0 16 16", :solid,
       ~S|<path d="M14.438 10.148c.19-.425-.321-.787-.748-.601A5.5 5.5 0 0 1 6.453 2.31c.186-.427-.176-.938-.6-.748a6.501 6.501 0 1 0 8.585 8.586Z"/>|}

  defp icon_data("hero-puzzle-piece"),
    do:
      {"0 0 24 24", :outline,
       ~S|<path stroke-linecap="round" stroke-linejoin="round" d="M14.25 6.087c0-.355.186-.676.401-.959.221-.29.349-.634.349-1.003 0-1.036-1.007-1.875-2.25-1.875s-2.25.84-2.25 1.875c0 .369.128.713.349 1.003.215.283.401.604.401.959v0a.64.64 0 0 1-.657.643 48.39 48.39 0 0 1-4.163-.3c.186 1.613.293 3.25.315 4.907a.656.656 0 0 1-.658.663v0c-.355 0-.676-.186-.959-.401a1.647 1.647 0 0 0-1.003-.349c-1.036 0-1.875 1.007-1.875 2.25s.84 2.25 1.875 2.25c.369 0 .713-.128 1.003-.349.283-.215.604-.401.959-.401v0c.31 0 .555.26.532.57a48.039 48.039 0 0 1-.642 5.056c1.518.19 3.058.309 4.616.354a.64.64 0 0 0 .657-.643v0c0-.355-.186-.676-.401-.959a1.647 1.647 0 0 1-.349-1.003c0-1.035 1.008-1.875 2.25-1.875 1.243 0 2.25.84 2.25 1.875 0 .369-.128.713-.349 1.003-.215.283-.4.604-.4.959v0c0 .333.277.599.61.58a48.1 48.1 0 0 0 5.427-.63 48.05 48.05 0 0 0 .582-4.717.532.532 0 0 0-.533-.57v0c-.355 0-.676.186-.959.401-.29.221-.634.349-1.003.349-1.035 0-1.875-1.007-1.875-2.25s.84-2.25 1.875-2.25c.37 0 .713.128 1.003.349.283.215.604.401.96.401v0a.656.656 0 0 0 .658-.663 48.422 48.422 0 0 0-.37-5.36c-1.886.342-3.81.574-5.766.689a.578.578 0 0 1-.61-.58v0Z"/>|}

  defp icon_data("hero-rocket-launch"),
    do:
      {"0 0 24 24", :outline,
       ~S|<path stroke-linecap="round" stroke-linejoin="round" d="M15.59 14.37a6 6 0 0 1-5.84 7.38v-4.8m5.84-2.58a14.98 14.98 0 0 0 6.16-12.12A14.98 14.98 0 0 0 9.631 8.41m5.96 5.96a14.926 14.926 0 0 1-5.841 2.58m-.119-8.54a6 6 0 0 0-7.381 5.84h4.8m2.581-5.84a14.927 14.927 0 0 0-2.58 5.84m2.699 2.7c-.103.021-.207.041-.311.06a15.09 15.09 0 0 1-2.448-2.448 14.9 14.9 0 0 1 .06-.312m-2.24 2.39a4.493 4.493 0 0 0-1.757 4.306 4.493 4.493 0 0 0 4.306-1.758M16.5 9a1.5 1.5 0 1 1-3 0 1.5 1.5 0 0 1 3 0Z"/>|}

  defp icon_data("hero-server-stack"),
    do:
      {"0 0 24 24", :outline,
       ~S|<path stroke-linecap="round" stroke-linejoin="round" d="M5.25 14.25h13.5m-13.5 0a3 3 0 0 1-3-3m3 3a3 3 0 1 0 0 6h13.5a3 3 0 1 0 0-6m-16.5-3a3 3 0 0 1 3-3h13.5a3 3 0 0 1 3 3m-19.5 0a4.5 4.5 0 0 1 .9-2.7L5.737 5.1a3.375 3.375 0 0 1 2.7-1.35h7.126c1.062 0 2.062.5 2.7 1.35l2.587 3.45a4.5 4.5 0 0 1 .9 2.7m0 0a3 3 0 0 1-3 3m0 3h.008v.008h-.008v-.008Zm0-6h.008v.008h-.008v-.008Zm-3 6h.008v.008h-.008v-.008Zm0-6h.008v.008h-.008v-.008Z"/>|}

  defp icon_data("hero-shield-check"),
    do:
      {"0 0 24 24", :outline,
       ~S|<path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75 11.25 15 15 9.75m-3-7.036A11.959 11.959 0 0 1 3.598 6 11.99 11.99 0 0 0 3 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285Z"/>|}

  defp icon_data("hero-sparkles"),
    do:
      {"0 0 24 24", :outline,
       ~S|<path stroke-linecap="round" stroke-linejoin="round" d="M9.813 15.904 9 18.75l-.813-2.846a4.5 4.5 0 0 0-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 0 0 3.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 0 0 3.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 0 0-3.09 3.09ZM18.259 8.715 18 9.75l-.259-1.035a3.375 3.375 0 0 0-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 0 0 2.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 0 0 2.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 0 0-2.456 2.456ZM16.894 20.567 16.5 21.75l-.394-1.183a2.25 2.25 0 0 0-1.423-1.423L13.5 18.75l1.183-.394a2.25 2.25 0 0 0 1.423-1.423l.394-1.183.394 1.183a2.25 2.25 0 0 0 1.423 1.423l1.183.394-1.183.394a2.25 2.25 0 0 0-1.423 1.423Z"/>|}

  defp icon_data("hero-squares-2x2"),
    do:
      {"0 0 24 24", :outline,
       ~S|<path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6A2.25 2.25 0 0 1 6 3.75h2.25A2.25 2.25 0 0 1 10.5 6v2.25a2.25 2.25 0 0 1-2.25 2.25H6a2.25 2.25 0 0 1-2.25-2.25V6ZM3.75 15.75A2.25 2.25 0 0 1 6 13.5h2.25a2.25 2.25 0 0 1 2.25 2.25V18a2.25 2.25 0 0 1-2.25 2.25H6A2.25 2.25 0 0 1 3.75 18v-2.25ZM13.5 6a2.25 2.25 0 0 1 2.25-2.25H18A2.25 2.25 0 0 1 20.25 6v2.25A2.25 2.25 0 0 1 18 10.5h-2.25a2.25 2.25 0 0 1-2.25-2.25V6ZM13.5 15.75a2.25 2.25 0 0 1 2.25-2.25H18a2.25 2.25 0 0 1 2.25 2.25V18A2.25 2.25 0 0 1 18 20.25h-2.25A2.25 2.25 0 0 1 13.5 18v-2.25Z"/>|}

  defp icon_data("hero-sun-micro"),
    do:
      {"0 0 16 16", :solid,
       ~S|<path d="M8 1a.75.75 0 0 1 .75.75v1.5a.75.75 0 0 1-1.5 0v-1.5A.75.75 0 0 1 8 1ZM10.5 8a2.5 2.5 0 1 1-5 0 2.5 2.5 0 0 1 5 0ZM12.95 4.11a.75.75 0 1 0-1.06-1.06l-1.062 1.06a.75.75 0 0 0 1.061 1.062l1.06-1.061ZM15 8a.75.75 0 0 1-.75.75h-1.5a.75.75 0 0 1 0-1.5h1.5A.75.75 0 0 1 15 8ZM11.89 12.95a.75.75 0 0 0 1.06-1.06l-1.06-1.062a.75.75 0 0 0-1.062 1.061l1.061 1.06ZM8 12a.75.75 0 0 1 .75.75v1.5a.75.75 0 0 1-1.5 0v-1.5A.75.75 0 0 1 8 12ZM5.172 11.89a.75.75 0 0 0-1.061-1.062L3.05 11.89a.75.75 0 1 0 1.06 1.06l1.06-1.06ZM4 8a.75.75 0 0 1-.75.75h-1.5a.75.75 0 0 1 0-1.5h1.5A.75.75 0 0 1 4 8ZM4.11 5.172A.75.75 0 0 0 5.173 4.11L4.11 3.05a.75.75 0 1 0-1.06 1.06l1.06 1.06Z"/>|}

  defp icon_data("hero-x-mark"),
    do:
      {"0 0 24 24", :outline,
       ~S|<path stroke-linecap="round" stroke-linejoin="round" d="M6 18 18 6M6 6l12 12"/>|}

  defp icon_data("hero-x-mark-micro"),
    do:
      {"0 0 16 16", :solid,
       ~S|<path d="M5.28 4.22a.75.75 0 0 0-1.06 1.06L6.94 8l-2.72 2.72a.75.75 0 1 0 1.06 1.06L8 9.06l2.72 2.72a.75.75 0 1 0 1.06-1.06L9.06 8l2.72-2.72a.75.75 0 0 0-1.06-1.06L8 6.94 5.28 4.22Z"/>|}

  defp icon_data(name) do
    raise ArgumentError, """
    unknown icon #{inspect(name)}.

    Icons are inlined from the heroicons dependency -- add a clause for it in
    McpRegistryWeb.CoreComponents (see the "Heroicon path data" section).
    """
  end
end
