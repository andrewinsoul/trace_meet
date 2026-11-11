defmodule TraceMeetWeb.UserRegistrationLive do
  use TraceMeetWeb, :live_view

  alias TraceMeet.Accounts
  alias TraceMeet.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})
    {:ok, assign(socket, form: to_form(changeset), page_title: "Create your account")}
  end

  @impl true
  def handle_event("validate", %{"user" => attrs}, socket) do
    changeset =
      %User{}
      |> Accounts.change_user_registration(attrs)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
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
              <p class="text-sm font-semibold text-[#087C43]">GET STARTED</p>
              <h1 class="mt-2 text-2xl font-semibold tracking-tight text-[#17231C]">
                Create your advisor account
              </h1>
              <p class="mt-2 text-sm leading-6 text-[#68756C]">
                Set up your workspace to turn client conversations into clear next steps.
              </p>
            </div>
            <.form
              for={@form}
              action={~p"/users/register"}
              method="post"
              phx-change="validate"
              class="space-y-4"
            >
              <.input
                field={@form[:email]}
                type="email"
                label="Work email"
                placeholder="you@company.com"
                autocomplete="email"
                required
              />
              <.input
                field={@form[:password]}
                type="password"
                label="Password"
                placeholder="At least 8 characters"
                autocomplete="new-password"
                required
              />
              <.input
                field={@form[:password_confirmation]}
                type="password"
                label="Confirm password"
                placeholder="Enter your password again"
                autocomplete="new-password"
                required
              />
              <.button type="submit" class="mt-2" loading_text="Creating account...">
                Create account
              </.button>
            </.form>
            <p class="mt-6 text-center text-sm text-[#68756C]">
              Already have an account?
              <.link
                navigate={~p"/users/log_in"}
                class="font-semibold text-[#087C43] hover:text-[#066B39]"
              >
                Sign in
              </.link>
            </p>
          </div>
          <p class="mt-6 text-center text-xs text-[#98A39A]">
            By creating an account, you agree to use TraceMeet responsibly.
          </p>
        </section>
      </main>
    </Layouts.app>
    """
  end
end
