defmodule TraceMeetWeb.DashboardLive do
  use TraceMeetWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Dashboard", active_page: :dashboard)}
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
        <p class="text-sm font-medium text-[#087C43]">YOUR WORKSPACE</p>
        <h1 class="mt-2 text-2xl font-semibold tracking-tight text-[#17231C] sm:text-3xl">
          Welcome to TraceMeet
        </h1>
        <p class="mt-2 max-w-2xl text-sm leading-6 text-[#68756C] sm:text-base">
          Your advisor workspace is ready. We'll build your client and meeting workflows here.
        </p>
      </div>

      <section class="rounded-2xl border border-[#E4EAE5] bg-white p-6 shadow-sm sm:p-8">
        <div class="flex h-12 w-12 items-center justify-center rounded-xl bg-[#E7F6ED] text-[#087C43]">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="h-6 w-6" aria-hidden="true">
            <path stroke-linecap="round" stroke-linejoin="round" d="m5 12 4 4L19 6" />
          </svg>
        </div>
        <h2 class="mt-5 text-lg font-semibold text-[#17231C]">Your account is set up</h2>
        <p class="mt-2 text-sm leading-6 text-[#66736A]">
          Signup and authentication are working. This is the dashboard page.
        </p>
      </section>
    </Layouts.workspace>
    """
  end
end
