defmodule TraceMeetWeb.UIComponents do
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  attr :field, Phoenix.HTML.FormField, required: true
  attr :type, :string, default: "text"
  attr :label, :string, default: nil
  attr :placeholder, :string, default: nil
  attr :hint, :string, default: nil
  attr :autocomplete, :string, default: nil
  attr :required, :boolean, default: false
  attr :class, :any, default: nil
  attr :rest, :global

  def input(assigns) do
    errors = Enum.map(assigns.field.errors, &translate_error/1)
    assigns = assign(assigns, :errors, errors)

    ~H"""
    <div class="space-y-1.5">
      <label :if={@label} for={@field.id} class="block text-sm font-medium text-[#26352B]">
        {@label}
      </label>
      <div class="relative">
        <input
          id={@field.id}
          name={@field.name}
          type={@type}
          value={Phoenix.HTML.Form.normalize_value(@type, @field.value)}
          placeholder={@placeholder}
          autocomplete={@autocomplete}
          required={@required}
          aria-invalid={@errors != []}
          aria-describedby={if @errors != [], do: "#{@field.id}-errors"}
          class={[
            "block w-full rounded-lg border bg-white px-3.5 py-3 text-sm !text-[#17231C] shadow-sm outline-none transition",
            @type == "password" && "pr-11",
            "!placeholder:text-[#9AA69D] focus:border-[#087C43] focus:ring-4 focus:ring-[#087C43]/10",
            @errors == [] && "border-[#DCE5DE]",
            @errors != [] && "border-red-500 focus:border-red-500 focus:ring-red-500/10",
            @class
          ]}
          {@rest}
        />
        <button
          :if={@type == "password"}
          type="button"
          phx-click={
            JS.toggle_attribute({"type", "password"}, to: "##{@field.id}")
            |> JS.toggle_class("hidden", to: "##{@field.id}-eye")
            |> JS.toggle_class("hidden", to: "##{@field.id}-eye-off")
          }
          class="absolute inset-y-0 right-3 inline-flex items-center text-[#68756C] hover:text-[#26352B] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#087C43] rounded"
          aria-label="Toggle password visibility"
        >
          <svg
            id={"#{@field.id}-eye"}
            class="h-5 w-5"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="1.8"
            aria-hidden="true"
          >
            <path d="M2.5 12s3.4-7 9.5-7 9.5 7 9.5 7-3.4 7-9.5 7-9.5-7-9.5-7Z" />
            <circle cx="12" cy="12" r="3" />
          </svg>
          <svg
            id={"#{@field.id}-eye-off"}
            class="hidden h-5 w-5"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="1.8"
            aria-hidden="true"
          >
            <path d="m3 3 18 18M10.6 10.6a2 2 0 0 0 2.8 2.8" />
            <path d="M9.9 5.2A10.8 10.8 0 0 1 12 5c6.1 0 9.5 7 9.5 7a15.8 15.8 0 0 1-3.1 3.9M6.2 6.2C3.8 7.8 2.5 12 2.5 12s3.4 7 9.5 7c1.2 0 2.3-.3 3.3-.7" />
          </svg>
        </button>
      </div>
      <p :if={@hint && @errors == []} class="text-xs text-[#68756C]">{@hint}</p>
      <div :if={@errors != []} id={"#{@field.id}-errors"} class="space-y-1" role="alert">
        <p :for={error <- @errors} class="text-sm text-red-600">{error}</p>
      </div>
    </div>
    """
  end

  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, default: nil
  attr :placeholder, :string, default: nil
  attr :rows, :integer, default: 4
  attr :required, :boolean, default: false
  attr :class, :any, default: nil
  attr :rest, :global

  def textarea(assigns) do
    errors = Enum.map(assigns.field.errors, &translate_error/1)
    assigns = assign(assigns, :errors, errors)

    ~H"""
    <div class="space-y-1.5">
      <label :if={@label} for={@field.id} class="block text-sm font-medium text-[#26352B]">
        {@label}
      </label>
      <textarea
        id={@field.id}
        name={@field.name}
        required={@required}
        rows={@rows}
        placeholder={@placeholder}
        aria-invalid={@errors != []}
        aria-describedby={if @errors != [], do: "#{@field.id}-errors"}
        class={[
          "block w-full rounded-lg border bg-white px-3.5 py-3 text-sm !text-[#17231C] shadow-sm outline-none transition",
          "!placeholder:text-[#9AA69D] focus:border-[#087C43] focus:ring-4 focus:ring-[#087C43]/10",
          @errors == [] && "border-[#DCE5DE]",
          @errors != [] && "border-red-500 focus:border-red-500 focus:ring-red-500/10",
          @class
        ]}
        {@rest}
      >{@field.value}</textarea>
      <div :if={@errors != []} id={"#{@field.id}-errors"} class="space-y-1" role="alert">
        <p :for={error <- @errors} class="text-sm text-red-600">{error}</p>
      </div>
    </div>
    """
  end

  attr :type, :string, default: "button"
  attr :variant, :string, default: "primary", values: ~w(primary secondary)
  attr :class, :any, default: nil
  attr :disabled, :boolean, default: false
  attr :loading_text, :string, default: "Please wait..."
  attr :rest, :global
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      disabled={@disabled}
      phx-disable-with={@loading_text}
      class={[
        "inline-flex w-full items-center justify-center gap-2 rounded-lg px-4 py-3 text-sm font-semibold transition",
        "focus:outline-none focus:ring-4 disabled:cursor-not-allowed disabled:opacity-65",
        @variant == "primary" && "bg-[#087C43] text-white shadow-sm hover:bg-[#066B39] focus:ring-[#087C43]/20",
        @variant == "secondary" && "border border-[#DCE5DE] bg-white text-[#26352B] hover:bg-[#F5F7F5]",
        @class
      ]}
      {@rest}
    >
      <svg
        class="hidden h-4 w-4 animate-spin [.phx-submit-loading_&]:inline-block"
        viewBox="0 0 24 24"
        fill="none"
        aria-hidden="true"
      >
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 0 1 8-8v4a4 4 0 0 0-4 4H4z" />
      </svg>
      <span>{render_slot(@inner_block)}</span>
    </button>
    """
  end

  attr :size, :string, default: "default", values: ~w(default compact)
  attr :class, :any, default: nil

  def brand(assigns) do
    ~H"""
    <a href="/" aria-label="TraceMeet home" class={["inline-flex items-center w-full gap-3", @class]}>
      <img
        src="/images/logo.svg"
        alt=""
        class={if @size == "compact", do: "h-9 w-9", else: "h-11 w-11"}
      />
      <span class="text-2xl font-semibold tracking-tight text-[#17231C]">TraceMeet</span>
    </a>
    """
  end

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end
