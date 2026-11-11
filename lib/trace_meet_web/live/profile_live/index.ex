defmodule TraceMeetWeb.ProfileLive.Index do
  use TraceMeetWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Profile", active_page: :settings_profile)}
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
        <p class="text-sm font-medium tracking-wide text-[#087C43]">ACCOUNT SETTINGS</p>
        <h1 class="mt-2 text-2xl font-semibold tracking-tight text-[#17231C] sm:text-3xl">
          Profile
        </h1>
        <p class="mt-2 max-w-2xl text-sm leading-6 text-[#68756C]">
          View the account information associated with your TraceMeet advisor account.
        </p>
      </div>

      <div class="grid gap-6 lg:grid-cols-[minmax(0,1fr)_320px]">
        <section class="rounded-2xl border border-[#E5EBE6] bg-white p-5 sm:p-7">
          <div class="flex items-center gap-4 border-b border-[#EEF2EF] pb-6">
            <div class="flex h-16 w-16 shrink-0 items-center justify-center rounded-2xl bg-[#EAF5EE] text-2xl font-semibold uppercase text-[#087C43]">
              {String.first(@current_user.email) |> String.upcase()}
            </div>
            <div class="min-w-0">
              <h2 class="text-lg font-semibold text-[#26352B]">Advisor account</h2>
              <p class="mt-1 truncate text-sm text-[#68756C]">{@current_user.email}</p>
            </div>
          </div>

          <div class="pt-6">
            <h3 class="text-sm font-semibold text-[#26352B]">Account information</h3>
            <div class="mt-4 space-y-5">
              <div>
                <label class="mb-1.5 block text-xs font-medium uppercase tracking-wide text-[#87938A]">
                  Email address
                </label>
                <div class="flex min-h-11 items-center rounded-lg border border-[#E5EBE6] bg-[#F7F9F7] px-3.5 py-2.5 text-sm text-[#526057]">
                  {@current_user.email}
                </div>
                <p class="mt-1.5 text-xs leading-5 text-[#87938A]">
                  This email address is used to sign in to TraceMeet. It cannot be changed here.
                </p>
              </div>

              <div>
                <label class="mb-1.5 block text-xs font-medium uppercase tracking-wide text-[#87938A]">
                  Account created
                </label>
                <div class="flex min-h-11 items-center rounded-lg border border-[#E5EBE6] bg-[#F7F9F7] px-3.5 py-2.5 text-sm text-[#526057]">
                  {Calendar.strftime(DateTime.to_date(@current_user.inserted_at), "%B %d, %Y")}
                </div>
              </div>
            </div>
          </div>
        </section>

        <aside class="h-fit rounded-2xl border border-[#E5EBE6] bg-white p-5">
          <div class="flex h-10 w-10 items-center justify-center rounded-xl bg-[#EAF5EE] text-[#087C43]">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" class="h-5 w-5" aria-hidden="true">
              <path d="M12 22s8-4 8-11V5l-8-3-8 3v6c0 7 8 11 8 11Z" />
              <path d="m9 12 2 2 4-4" />
            </svg>
          </div>
          <h2 class="mt-4 text-sm font-semibold text-[#26352B]">Your account is secure</h2>
          <p class="mt-1.5 text-sm leading-6 text-[#68756C]">
            Your sign-in credentials are protected. You can manage your password and account security from the Security section.
          </p>
          <.link
            navigate={~p"/settings/security"}
            class="mt-4 inline-flex items-center gap-2 text-sm font-semibold text-[#087C43] hover:text-[#066A39]"
          >
            Go to Security
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" class="h-4 w-4" aria-hidden="true">
              <path d="M5 12h14M13 6l6 6-6 6" />
            </svg>
          </.link>
        </aside>
      </div>
    </Layouts.workspace>
    """
  end
end
