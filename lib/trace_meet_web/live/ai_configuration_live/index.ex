defmodule TraceMeetWeb.AIConfigurationLive.Index do
  use TraceMeetWeb, :live_view

  alias TraceMeet.AI.Configuration

  @impl true
  def mount(params, _session, socket) do
    socket = load_data(socket)

    if socket.assigns.prompts == [] or params["new"] == "true" do
      {:ok,
       assign(socket,
         form:
           to_form(%{
             "name" => "",
             "meeting_type" => "general_consultation",
             "other_meeting_type" => "",
             "instructions" => "",
             "is_default" => "true"
           })
       )}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_event("cancel", _params, socket),
    do: {:noreply, assign(socket, form: nil)}

  def handle_event("new", _params, socket) do
    {:noreply,
     assign(socket,
       form:
         to_form(%{
           "name" => "",
           "meeting_type" => "general_consultation",
           "other_meeting_type" => "",
           "instructions" => "",
           "is_default" => if(socket.assigns.prompts == [], do: "true", else: "false")
         })
     )}
  end

  def handle_event("view", %{"id" => id}, socket) do
    case Configuration.get_advisor_prompt(socket.assigns.current_user.id, id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Prompt configuration not found.")}

      prompt ->
        version = Enum.find(prompt.versions, &(&1.version == prompt.active_version))

        {:noreply,
         assign(socket,
           viewing: if(socket.assigns.viewing == id, do: nil, else: id),
           viewed_instructions: version && version.instructions
         )}
    end
  end

  def handle_event("meeting_type_changed", %{"prompt" => attrs}, socket) do
    {:noreply, assign(socket, :form, to_form(attrs, as: :prompt))}
  end

  def handle_event("save", %{"prompt" => attrs}, socket) do
    advisor_id = socket.assigns.current_user.id

    result = Configuration.create_advisor_prompt(advisor_id, attrs)

    case result do
      {:ok, _} ->
        message =
          if socket.assigns.prompts == [],
            do: "Your default AI configuration is ready. You can now process transcripts.",
            else: "Prompt configuration saved."

        {:noreply,
         socket
         |> assign(form: nil, viewing: nil, viewed_instructions: nil)
         |> load_data()
         |> put_flash(:info, message)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(attrs, as: :prompt, errors: changeset.errors))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "The prompt configuration could not be saved.")}
    end
  end

  def handle_event("default", %{"id" => id}, socket) do
    case Configuration.set_default(socket.assigns.current_user.id, id) do
      {:ok, _} -> {:noreply, socket |> load_data() |> put_flash(:info, "Default prompt updated.")}
      _ -> {:noreply, put_flash(socket, :error, "The default prompt could not be updated.")}
    end
  end

  defp load_data(socket) do
    advisor_id = socket.assigns.current_user.id

    prompts = Configuration.list_advisor_prompts(advisor_id)

    assign(socket,
      page_title: "AI Configuration",
      active_page: :ai_configuration,
      guardrails: Configuration.list_guardrails(),
      meeting_types: TraceMeet.Meetings.Types.all(),
      prompts: prompts,
      viewing: Map.get(socket.assigns, :viewing),
      viewed_instructions: Map.get(socket.assigns, :viewed_instructions),
      form: Map.get(socket.assigns, :form),
      has_prompts: prompts != []
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.workspace flash={@flash} current_user={@current_user} active_page={:ai_configuration}>
      <div class="mb-8 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p class="text-sm font-medium tracking-wide text-[#087C43]">AI PERSONALIZATION</p>
          <h1 class="mt-2 text-2xl font-semibold tracking-tight text-[#17231C] sm:text-3xl">
            AI Configuration
          </h1>
          <p class="mt-2 max-w-2xl text-sm leading-6 text-[#68756C]">
            Customize what TraceMeet pays attention to while its foundational reliability rules remain in place.
          </p>
        </div>
        <button
          type="button"
          phx-click="new"
          class="rounded-lg bg-[#087C43] px-4 py-2.5 text-sm font-semibold text-white hover:bg-[#066A39]"
        >
          New prompt configuration
        </button>
      </div>

      <div class="grid gap-6 xl:grid-cols-[1.2fr_0.8fr]">
        <section class="space-y-4">
          <div class="rounded-2xl border border-[#E5EBE6] bg-white p-5 sm:p-6">
            <h2 class="text-lg font-semibold text-[#26352B]">Your prompt configurations</h2>
            <p class="mt-1 text-sm text-[#68756C]">
              Create reusable instructions for different advisory contexts.
            </p>
            <div
              :if={@prompts == []}
              class="mt-5 rounded-xl border border-dashed border-[#DCE5DE] p-6 text-center"
            >
              <p class="text-sm font-medium text-[#26352B]">No configurations yet</p>
              <p class="mt-1 text-xs text-[#68756C]">
                Create one to tailor transcript analysis to your practice.
              </p>
            </div>
            <div :for={prompt <- @prompts} class="mt-4 rounded-xl border border-[#E5EBE6] p-4">
              <div class="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <div class="flex flex-wrap items-center gap-2">
                    <h3 class="font-semibold text-[#26352B]">{prompt.name}</h3>
                    <span
                      :if={prompt.is_default}
                      class="rounded-full bg-[#EAF5EE] px-2.5 py-1 text-xs font-semibold text-[#087C43]"
                    >
                      Default
                    </span>
                  </div>
                  <p class="mt-1 text-xs text-[#68756C]">
                    {TraceMeet.Meetings.Types.label(prompt.meeting_type)}{if prompt.meeting_type ==
                                                                               "other" and
                                                                               prompt.other_meeting_type,
                                                                             do:
                                                                               " · " <>
                                                                                 prompt.other_meeting_type,
                                                                             else: ""} · Version {prompt.active_version}
                  </p>
                </div>
                <div class="flex gap-2">
                  <button
                    type="button"
                    phx-click="view"
                    phx-value-id={prompt.id}
                    class="rounded-lg border border-[#DCE5DE] px-3 py-1.5 text-xs font-semibold text-[#526057]"
                  >
                    {if @viewing == prompt.id, do: "Hide instructions", else: "View instructions"}
                  </button>
                  <button
                    :if={!prompt.is_default}
                    type="button"
                    phx-click="default"
                    phx-value-id={prompt.id}
                    class="rounded-lg border border-[#DCE5DE] px-3 py-1.5 text-xs font-semibold text-[#526057]"
                  >
                    Make default
                  </button>
                </div>
              </div>
              <div class="mt-3 space-y-1">
                <p :for={version <- Enum.take(prompt.versions, 3)} class="text-xs text-[#87938A]">
                  Version {version.version} · {String.slice(version.sha256, 0, 12)}
                </p>
              </div>
              <div
                :if={@viewing == prompt.id}
                class="mt-3 rounded-lg bg-[#F6F8F6] p-3 text-sm leading-6 text-[#526057] whitespace-pre-wrap"
              >
                {@viewed_instructions}
              </div>
            </div>
          </div>

          <section :if={@form} class="rounded-2xl border border-[#C9D7CC] bg-white p-5 sm:p-6">
            <h2 class="text-lg font-semibold text-[#26352B]">
              New prompt configuration
            </h2>
            <p class="mt-1 text-xs leading-5 text-[#68756C]">
              Prompt configurations are immutable. To change your instructions, create a new configuration. Previous configurations remain available in processing history.
            </p>
            <.form for={@form} as={:prompt} phx-submit="save" class="mt-5 space-y-4">
              <div>
                <label class="mb-1.5 block text-sm font-medium text-[#26352B]">
                  Configuration name
                </label>
                <.input field={@form[:name]} placeholder="e.g. Business strategy" />
              </div>
              <div>
                <label
                  for="prompt-meeting-type"
                  class="mb-1.5 block text-sm font-medium text-[#26352B]"
                >
                  Meeting type
                </label>
                <select
                  id="prompt-meeting-type"
                  name="prompt[meeting_type]"
                  phx-change="meeting_type_changed"
                  class="block w-full rounded-lg border border-[#DCE5DE] bg-white px-3.5 py-3 text-sm text-[#17231C] outline-none focus:border-[#087C43] focus:ring-4 focus:ring-[#087C43]/10"
                >
                  <option
                    :for={{label, value} <- @meeting_types}
                    value={value}
                    selected={@form[:meeting_type].value == value}
                  >
                    {label}
                  </option>
                </select>
                <div :if={@form[:meeting_type].value == "other"} class="mt-3">
                  <label class="mb-1.5 block text-sm font-medium text-[#26352B]">
                    Specify meeting type
                  </label>
                  <.input field={@form[:other_meeting_type]} placeholder="e.g. Regulatory compliance" />
                </div>
              </div>
              <div>
                <label class="mb-1.5 block text-sm font-medium text-[#26352B]">
                  Additional instructions
                </label>
                <.textarea
                  field={@form[:instructions]}
                  rows={7}
                  required
                  placeholder="Tell TraceMeet what to pay particular attention to..."
                />
              </div>
              <label class="flex items-center gap-2 text-sm text-[#526057]">
                <input
                  type="checkbox"
                  name="prompt[is_default]"
                  value="true"
                  checked={@form[:is_default].value in [true, "true", "on"]}
                  disabled={@prompts == []}
                  class="rounded border-[#C9D7CC] text-[#087C43] focus:ring-[#087C43] disabled:opacity-70"
                /> Use as my default configuration
              </label>
              <p :if={!@has_prompts} class="text-xs text-[#68756C]">
                Your first configuration is automatically set as the default.
              </p>
              <div class="flex gap-2">
                <button
                  type="submit"
                  class="rounded-lg bg-[#087C43] px-4 py-2.5 text-sm font-semibold text-white"
                >
                  Save configuration
                </button>
                <button
                  type="button"
                  phx-click="cancel"
                  class="rounded-lg border border-[#DCE5DE] px-4 py-2.5 text-sm font-semibold text-[#526057]"
                >
                  Cancel
                </button>
              </div>
            </.form>
          </section>
        </section>

        <aside class="h-fit self-start rounded-2xl border border-[#E5EBE6] py-8 bg-white p-5 sm:p-6">
          <h2 class="text-lg font-semibold text-[#26352B]">TraceMeet guardrails</h2>
          <p class="mt-1 text-sm leading-6 text-[#68756C]">
            These platform-wide rules are seeded and versioned separately. They are included automatically and cannot be changed from advisor settings.
          </p>
          <div :for={guardrail <- @guardrails} class="border-t border-[#EEF2EF] py-4 first:mt-4">
            <div class="flex items-center justify-between gap-2">
              <h3 class="text-sm font-semibold text-[#26352B]">{guardrail.name}</h3>
              <div class="flex items-center gap-2">
                <span class="rounded-full bg-[#F0F4F1] px-2 py-1 text-[10px] font-medium text-[#526057]">
                  {if guardrail.scope == "global",
                    do: "Global",
                    else: TraceMeet.Meetings.Types.label(guardrail.meeting_type)}
                </span>
                <span class="text-[11px] text-[#87938A]">v{guardrail.active_version}</span>
              </div>
            </div>
            <p class="mt-1 text-xs leading-5 text-[#68756C]">
              {guardrail.versions
              |> Enum.find(&(&1.version == guardrail.active_version))
              |> then(fn version -> version && version.instruction end)}
            </p>
          </div>
        </aside>
      </div>
    </Layouts.workspace>
    """
  end
end
