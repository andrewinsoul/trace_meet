defmodule TraceMeetWeb.DashboardLive do
  use TraceMeetWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Dashboard")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="min-h-screen bg-[#F7F9F7]">
        <header class="border-b border-[#E7ECE8] bg-white">
          <div class="mx-auto flex max-w-7xl items-center justify-between px-6 py-4">
            <a href={~p"/dashboard"} class="flex items-center gap-3">
              <img src={~p"/images/logo.svg"} alt="TraceMeet" class="h-9 w-9" />
              <span class="text-xl font-semibold tracking-tight text-[#17231C]">TraceMeet</span>
            </a>
            <div class="flex items-center gap-4">
              <span class="hidden text-sm text-[#66736A] sm:block">{@current_user.email}</span>
              <.form for={to_form(%{})} action={~p"/users/log_out"} method="post">
                <button class="rounded-lg border border-[#DDE5DF] px-4 py-2 text-sm font-medium text-[#344139] transition hover:bg-[#F5F8F5]">
                  Sign out
                </button>
              </.form>
            </div>
          </div>
        </header>
        <main class="mx-auto max-w-7xl px-6 py-12">
          <p class="text-sm font-medium text-[#087C43]">YOUR WORKSPACE</p>
          <h1 class="mt-2 text-3xl font-semibold tracking-tight text-[#17231C]">Welcome to TraceMeet</h1>
          <p class="mt-3 max-w-2xl text-[#66736A]">
            Your advisor workspace is ready. We'll build your client and meeting workflows here.
          </p>
          <div class="mt-10 rounded-2xl border border-[#E4EAE5] bg-white p-8 shadow-sm">
            <div class="flex h-12 w-12 items-center justify-center rounded-xl bg-[#E7F6ED] text-[#087C43]">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="h-6 w-6" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" d="m5 12 4 4L19 6" />
              </svg>
            </div>
            <h2 class="mt-5 text-lg font-semibold text-[#17231C]">Your account is set up</h2>
            <p class="mt-2 text-sm leading-6 text-[#66736A]">
              Signup and authentication are working. The next milestone is client management.
            </p>
          </div>
        </main>
      </div>
    </Layouts.app>
    """
  end
end
