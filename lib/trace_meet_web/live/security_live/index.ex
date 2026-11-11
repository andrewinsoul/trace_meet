defmodule TraceMeetWeb.SecurityLive.Index do
  use TraceMeetWeb, :live_view

  alias TraceMeet.Accounts
  alias TraceMeet.Accounts.User
  alias TraceMeetWeb.Endpoint

  @impl true
  def mount(_params, _session, socket) do
    changeset = User.password_changeset(socket.assigns.current_user, %{})

    {:ok,
     assign(socket,
       page_title: "Security",
       active_page: :settings_security,
       form: to_form(changeset)
     )}
  end

  @impl true
  def handle_event("validate", %{"user" => attrs}, socket) do
    changeset =
      socket.assigns.current_user
      |> User.password_changeset(attrs)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"user" => attrs}, socket) do
    case Accounts.update_user_password(socket.assigns.current_user, attrs) do
      {:ok, user} ->
        Accounts.delete_user_session_tokens(user)
        Endpoint.broadcast("users_sessions:#{user.id}", "disconnect", %{})

        {:noreply,
         socket
         |> put_flash(:info, "Your password has been changed. Please sign in again.")
         |> redirect(to: ~p"/users/log_in")}

      {:error, :invalid_current_password} ->
        {:noreply,
         socket
         |> put_flash(:error, "Your current password is incorrect.")
         |> assign(:form, to_form(User.password_changeset(socket.assigns.current_user, attrs)))}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
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
        <p class="text-sm font-medium tracking-wide text-[#087C43]">ACCOUNT SECURITY</p>
        <h1 class="mt-2 text-2xl font-semibold tracking-tight text-[#17231C] sm:text-3xl">
          Security
        </h1>
        <p class="mt-2 max-w-2xl text-sm leading-6 text-[#68756C]">
          Keep your TraceMeet account protected by managing your password and understanding your active session.
        </p>
      </div>

      <div class="grid gap-6 lg:grid-cols-[minmax(0,1fr)_320px]">
        <section class="rounded-2xl border border-[#E5EBE6] bg-white p-5 sm:p-7">
          <div class="flex items-start gap-3 border-b border-[#EEF2EF] pb-5">
            <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-[#EAF5EE] text-[#087C43]">
              <svg
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="1.8"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="h-5 w-5"
                aria-hidden="true"
              >
                <rect x="4" y="10" width="16" height="11" rx="2" />
                <path d="M8 10V7a4 4 0 0 1 8 0v3M12 14v3" />
              </svg>
            </div>
            <div>
              <h2 class="text-base font-semibold text-[#26352B]">Change password</h2>
              <p class="mt-1 text-sm leading-6 text-[#68756C]">
                Use a strong password you don't use for other services.
              </p>
            </div>
          </div>

          <.form
            for={@form}
            id="security-password-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-5 pt-6"
          >
            <.input
              field={@form[:current_password]}
              type="password"
              label="Current password"
              placeholder="Enter your current password"
              autocomplete="current-password"
              required
            />
            <.input
              field={@form[:password]}
              type="password"
              label="New password"
              placeholder="At least 8 characters"
              autocomplete="new-password"
              required
              hint="Use between 8 and 128 characters."
            />
            <.input
              field={@form[:password_confirmation]}
              type="password"
              label="Confirm new password"
              placeholder="Re-enter your new password"
              autocomplete="new-password"
              required
            />

            <div class="flex flex-col-reverse gap-3 border-t border-[#EEF2EF] pt-5 sm:flex-row sm:justify-end">
              <.button type="submit" class="sm:w-auto" loading_text="Updating password...">
                Update password
              </.button>
            </div>
          </.form>
        </section>

        <aside class="h-fit rounded-2xl border border-[#E5EBE6] bg-white p-5">
          <div class="flex h-10 w-10 items-center justify-center rounded-xl bg-[#EAF5EE] text-[#087C43]">
            <svg
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="1.8"
              stroke-linecap="round"
              stroke-linejoin="round"
              class="h-5 w-5"
              aria-hidden="true"
            >
              <path d="M12 22s8-4 8-11V5l-8-3-8 3v6c0 7 8 11 8 11Z" />
              <path d="m9 12 2 2 4-4" />
            </svg>
          </div>
          <h2 class="mt-4 text-sm font-semibold text-[#26352B]">Single active session</h2>
          <p class="mt-1.5 text-sm leading-6 text-[#68756C]">
            Your advisor account can be signed in on one device at a time. Signing in elsewhere ends the previous session automatically.
          </p>
          <div class="mt-4 rounded-lg bg-[#F5F8F5] px-3.5 py-3">
            <p class="text-xs font-medium text-[#526057]">Session policy</p>
            <p class="mt-1 text-sm font-semibold text-[#087C43]">One active session per account</p>
          </div>
          <p class="mt-4 text-xs leading-5 text-[#87938A]">
            Changing your password signs out your current session and requires you to sign in again with your new password.
          </p>
        </aside>
      </div>
    </Layouts.workspace>
    """
  end
end
