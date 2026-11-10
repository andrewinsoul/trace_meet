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

  attr :flash, :map, required: true
  attr :current_user, :any, required: true
  attr :active_page, :atom, required: true
  slot :inner_block, required: true

  def workspace(assigns) do
    assigns =
      assign(assigns, :navigation, [
        %{key: :dashboard, label: "Dashboard", path: ~p"/dashboard", icon: "dashboard"},
        %{key: :clients, label: "Clients", path: ~p"/clients", icon: "clients"},
        %{key: :meetings, label: "Meetings", path: ~p"/meetings", icon: "meetings"},
        %{key: :actions, label: "Action items", path: ~p"/actions", icon: "actions"},
        %{key: :ai_configuration, label: "AI Configuration", path: ~p"/ai-configuration", icon: "ai"},
        %{key: :settings, label: "Settings", path: ~p"/settings", icon: "settings"}
      ])

    ~H"""
    <.app flash={@flash}>
      <div class="min-h-screen bg-[#F7F9F7]">
        <div
          id="app-sidebar-backdrop"
          class="fixed inset-0 z-40 hidden bg-[#102016]/40 lg:hidden"
          phx-click={close_sidebar()}
          aria-hidden="true"
        >
        </div>

        <aside
          id="app-sidebar"
          class="fixed inset-y-0 left-0 z-50 flex w-64 -translate-x-full flex-col border-r border-[#E5EBE6] bg-white transition-transform duration-200 ease-out lg:translate-x-0"
          aria-label="Main navigation"
        >
          <div class="flex h-20 items-center border-b border-[#EEF2EF] px-6">
            <.brand />
          </div>

          <nav class="flex-1 space-y-1 px-3 py-6">
            <p class="px-3 pb-3 text-[11px] font-semibold uppercase tracking-[0.12em] text-[#98A39A]">
              Workspace
            </p>
            <.link
              :for={item <- @navigation}
              navigate={item.path}
              phx-click={close_sidebar()}
              aria-current={if @active_page == item.key, do: "page"}
              class={[
                "group flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors",
                @active_page == item.key &&
                  "bg-[#EAF5EE] text-[#087C43]",
                @active_page != item.key &&
                  "text-[#59665D] hover:bg-[#F5F8F5] hover:text-[#17231C]"
              ]}
            >
              <.nav_icon
                name={item.icon}
                class={[
                  "h-5 w-5 shrink-0",
                  @active_page == item.key && "text-[#087C43]",
                  @active_page != item.key && "text-[#87938A] group-hover:text-[#526057]"
                ]}
              />
              <span>{item.label}</span>
              <span
                :if={@active_page == item.key}
                class="ml-auto h-1.5 w-1.5 rounded-full bg-[#087C43]"
              >
              </span>
            </.link>
          </nav>

          <div class="border-t border-[#EEF2EF] p-4">
            <div class="flex items-center gap-3 rounded-lg px-2 py-2">
              <div class="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-[#EAF5EE] text-sm font-semibold text-[#087C43]">
                {user_initial(@current_user.email)}
              </div>
              <div class="min-w-0 flex-1">
                <p class="truncate text-sm font-medium text-[#26352B]">Advisor account</p>
                <p class="truncate text-xs text-[#87938A]">{@current_user.email}</p>
              </div>
            </div>
            <.form for={to_form(%{})} action={~p"/users/log_out"} method="post" class="mt-2">
              <button
                type="submit"
                class="flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium text-[#68756C] transition-colors hover:bg-[#F5F8F5] hover:text-[#17231C]"
              >
                <.nav_icon name="logout" class="h-5 w-5 text-[#87938A]" />
                Sign out
              </button>
            </.form>
          </div>
        </aside>

        <div class="min-h-screen lg:pl-64">
          <header class="sticky top-0 z-30 flex h-16 items-center justify-between border-b border-[#E5EBE6] bg-white/95 px-4 backdrop-blur sm:px-6 lg:hidden">
            <button
              type="button"
              phx-click={toggle_sidebar()}
              aria-label="Toggle navigation"
              aria-controls="app-sidebar"
              class="inline-flex h-10 w-10 items-center justify-center rounded-lg text-[#526057] transition hover:bg-[#F5F8F5] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#087C43]"
            >
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" class="h-6 w-6" aria-hidden="true">
                <path stroke-linecap="round" d="M4 6h16M4 12h16M4 18h16" />
              </svg>
            </button>
            <.brand size="compact" class="w-auto" />
            <span class="w-10"></span>
          </header>

          <main class="mx-auto w-full px-4 py-6 sm:px-6 sm:py-8 lg:w-[98%] lg:px-0">
            {render_slot(@inner_block)}
          </main>
        </div>
      </div>
    </.app>
    """
  end

  attr :name, :string, required: true
  attr :class, :any, default: "h-5 w-5"

  def nav_icon(assigns) do
    paths = %{
      "dashboard" => ["M3 3h7v7H3z", "M14 3h7v7h-7z", "M14 14h7v7h-7z", "M3 14h7v7H3z"],
      "clients" => ["M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2", "M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8", "M20 21v-2a4 4 0 0 0-3-3.87", "M16 3.13a4 4 0 0 1 0 7.75"],
      "meetings" => ["M8 2v4", "M16 2v4", "M3 10h18", "M5 4h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2Z", "m9 16 2 2 4-4"],
      "actions" => ["M9 11l3 3L22 4", "M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"],
      "ai" => ["M12 3v3", "M5.6 5.6l2.1 2.1", "M3 12h3", "M18 12h3", "M16.3 7.7l2.1-2.1", "M9 16a4 4 0 1 1 6 0c-.8.7-1 1.2-1 2h-4c0-.8-.2-1.3-1-2Z", "M10 21h4"],
      "settings" => ["M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8", "M19.4 15a1.7 1.7 0 0 0 .34 1.88l.06.06-1.7 2.94-.08-.02a1.7 1.7 0 0 0-1.7.5l-.06.06h-3.4l-.03-.08a1.7 1.7 0 0 0-1.3-1.15l-.08-.02-1.7-2.94.06-.06A1.7 1.7 0 0 0 9.8 14.3l-.08-.02v-3.4l.08-.03a1.7 1.7 0 0 0 1.15-1.3l.02-.08 2.94-1.7.06.06a1.7 1.7 0 0 0 1.88.34l.06-.06h3.4l.03.08a1.7 1.7 0 0 0 1.3 1.15l.08.02v3.4l-.08.03A1.7 1.7 0 0 0 19.4 15Z"],
      "logout" => ["M10 17l5-5-5-5", "M15 12H3", "M12 3h6a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-6"]
    }

    assigns = assign(assigns, :paths, Map.fetch!(paths, assigns.name))

    ~H"""
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" class={@class} aria-hidden="true">
      <path :for={path <- @paths} d={path} />
    </svg>
    """
  end

  defp toggle_sidebar do
    JS.toggle_class("-translate-x-full", to: "#app-sidebar")
    |> JS.toggle(to: "#app-sidebar-backdrop")
  end

  defp close_sidebar do
    JS.add_class("-translate-x-full", to: "#app-sidebar")
    |> JS.hide(to: "#app-sidebar-backdrop")
  end

  defp user_initial(email) do
    email
    |> String.first()
    |> String.upcase()
  end

end
