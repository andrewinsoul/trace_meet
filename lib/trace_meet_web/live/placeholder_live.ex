defmodule TraceMeetWeb.PlaceholderLive do
  use TraceMeetWeb, :live_view

  @pages %{
    actions: %{
      title: "Action items",
      eyebrow: "FOLLOW-UP TRACKING",
      description: "Keep commitments and next steps visible until they're completed.",
      message: "Your action items will appear here",
      detail:
        "Approved actions from your meetings will be tracked here with owners, due dates and statuses."
    },
    settings: %{
      title: "Settings",
      eyebrow: "WORKSPACE PREFERENCES",
      description: "Manage your TraceMeet workspace preferences.",
      message: "Workspace settings are coming later",
      detail:
        "We'll add the essential account and workspace preferences here when they're needed."
    }
  }

  @impl true
  def mount(_params, _session, socket) do
    page = Map.fetch!(@pages, socket.assigns.live_action)

    {:ok,
     assign(socket,
       page_title: page.title,
       active_page: socket.assigns.live_action,
       page: page
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.workspace
      flash={@flash}
      current_user={@current_user}
      active_page={@active_page}
    >
      <div class="mb-8">
        <p class="text-sm font-medium tracking-wide text-[#087C43]">{@page.eyebrow}</p>
        <h1 class="mt-2 text-2xl font-semibold tracking-tight text-[#17231C] sm:text-3xl">
          {@page.title}
        </h1>
        <p class="mt-2 text-sm leading-6 text-[#68756C] sm:text-base">{@page.description}</p>
      </div>

      <section class="flex min-h-[340px] flex-col items-center justify-center rounded-2xl border border-dashed border-[#DCE5DE] bg-white px-6 py-12 text-center">
        <div class="flex h-14 w-14 items-center justify-center rounded-2xl bg-[#EAF5EE] text-[#087C43]">
          <svg
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="1.6"
            class="h-7 w-7"
            aria-hidden="true"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M4 5.5A2.5 2.5 0 0 1 6.5 3H20v16H6.5A2.5 2.5 0 0 0 4 21V5.5Z"
            />
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M4 18.5A2.5 2.5 0 0 1 6.5 16H20M8 7h8M8 10h6"
            />
          </svg>
        </div>
        <h2 class="mt-5 text-lg font-semibold text-[#26352B]">{@page.message}</h2>
        <p class="mt-2 max-w-md text-sm leading-6 text-[#68756C]">{@page.detail}</p>
      </section>
    </Layouts.workspace>
    """
  end
end
