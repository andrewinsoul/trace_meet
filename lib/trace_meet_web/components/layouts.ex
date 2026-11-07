defmodule TraceMeetWeb.Layouts do
  use TraceMeetWeb, :html

  embed_templates "layouts/*"

  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <main>
      {render_slot(@inner_block)}
    </main>
    <.flash_group flash={@flash} />
    """
  end

  attr :flash, :map, required: true
  attr :id, :string, default: "flash-group"

  def flash_group(assigns) do
    assigns =
      assign(assigns,
        info: Phoenix.Flash.get(assigns.flash, :info),
        error: Phoenix.Flash.get(assigns.flash, :error)
      )

    ~H"""
    <div id={@id} aria-live="polite" class="pointer-events-none fixed right-4 top-4 z-50 space-y-3">
      <div
        :if={@info}
        id="flash-info"
        role="alert"
        class="flash-toast pointer-events-auto flex w-80 items-start gap-3 rounded-lg border border-[#B7DFC7] bg-white p-4 text-sm text-[#174D31] shadow-lg"
        phx-click={JS.push("lv:clear-flash", value: %{key: :info}) |> JS.hide(to: "#flash-info")}
      >
        <span class="flex-1">{@info}</span>
        <button type="button" aria-label="Close" class="text-[#68756C]">×</button>
      </div>
      <div
        :if={@error}
        id="flash-error"
        role="alert"
        class="flash-toast pointer-events-auto flex w-80 items-start gap-3 rounded-lg border border-red-200 bg-white p-4 text-sm text-red-700 shadow-lg"
        phx-click={JS.push("lv:clear-flash", value: %{key: :error}) |> JS.hide(to: "#flash-error")}
      >
        <span class="flex-1">{@error}</span>
        <button type="button" aria-label="Close" class="text-red-500">×</button>
      </div>
      <div
        id="client-error"
        class="hidden rounded-lg border border-red-200 bg-white p-4 text-sm text-red-700 shadow-lg"
        phx-disconnected={JS.show(to: "#client-error")}
        phx-connected={JS.hide(to: "#client-error")}
      >
        We can't find the internet. Attempting to reconnect.
      </div>
      <div
        id="server-error"
        class="hidden rounded-lg border border-red-200 bg-white p-4 text-sm text-red-700 shadow-lg"
        phx-disconnected={JS.show(to: "#server-error")}
        phx-connected={JS.hide(to: "#server-error")}
      >
        Something went wrong. Attempting to reconnect.
      </div>
    </div>
    """
  end
end
