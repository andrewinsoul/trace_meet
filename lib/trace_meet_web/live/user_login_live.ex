defmodule TraceMeetWeb.UserLoginLive do
  use TraceMeetWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: :user), page_title: "Sign in")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <main class="flex min-h-screen items-center justify-center bg-[#F7F9F7] px-5 py-12">
        <section class="w-full max-w-md">
          <.brand class="mb-8 justify-center" />
          <div class="rounded-2xl border border-[#E5EBE6] bg-white p-7 shadow-[0_12px_40px_rgba(20,50,30,0.06)] sm:p-9">
            <div class="mb-7">
              <p class="text-sm font-semibold text-[#087C43]">WELCOME BACK</p>
              <h1 class="mt-2 text-2xl font-semibold tracking-tight text-[#17231C]">Sign in to TraceMeet</h1>
              <p class="mt-2 text-sm leading-6 text-[#68756C]">
                Pick up where you left off with your client meetings and follow-ups.
              </p>
            </div>
            <.form for={@form} action={~p"/users/log_in"} method="post" class="space-y-4">
              <.input field={@form[:email]} type="email" label="Work email" placeholder="you@company.com" autocomplete="email" required />
              <.input field={@form[:password]} type="password" label="Password" placeholder="Your password" autocomplete="current-password" required />
              <.button type="submit" class="mt-2" loading_text="Signing in...">
                Sign in
              </.button>
            </.form>
            <p class="mt-6 text-center text-sm text-[#68756C]">
              New to TraceMeet?
              <.link navigate={~p"/users/register"} class="font-semibold text-[#087C43] hover:text-[#066B39]">Create an account</.link>
            </p>
          </div>
          <p class="mt-6 text-center text-xs text-[#98A39A]">Secure access to your advisor workspace.</p>
        </section>
      </main>
    </Layouts.app>
    """
  end
end
