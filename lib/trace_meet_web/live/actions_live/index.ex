defmodule TraceMeetWeb.ActionsLive.Index do
  use TraceMeetWeb, :live_view

  alias TraceMeet.Extractions

  @statuses ~w(pending approved rejected)
  @categories [
    {"All categories", ""},
    {"Decisions", "decision"},
    {"Action items", "action_item"},
    {"Commitments", "commitment"},
    {"Risks", "risk"},
    {"Unresolved questions", "unresolved_question"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Action items",
       active_page: :actions,
       status: "pending",
       category: "",
       proposals: [],
       page: 1,
       page_size: 10,
       total_count: 0,
       total_pages: 1,
       counts: %{},
       categories: @categories
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    status = if params["status"] in @statuses, do: params["status"], else: "pending"
    category = params["category"] || ""
    page = parse_page(params["page"])

    {:noreply, load_proposals(socket, status, category, page)}
  end

  @impl true
  def handle_event("filter", params, socket) do
    status = if params["status"] in @statuses, do: params["status"], else: "pending"
    category = params["category"] || ""

    {:noreply,
     push_patch(socket,
       to: ~p"/actions?#{%{status: status, category: category, page: 1}}"
     )}
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    page = parse_page(page)

    {:noreply,
     push_patch(socket,
       to:
         ~p"/actions?#{%{status: socket.assigns.status, category: socket.assigns.category, page: page}}"
     )}
  end

  def handle_event("approve", %{"id" => id}, socket) do
    case Extractions.review_proposal(socket.assigns.current_user.id, id, "approved") do
      {:ok, _proposal} ->
        {:noreply,
         socket
         |> put_flash(:info, "Proposal approved and added to the advisor's records.")
         |> load_proposals(socket.assigns.status, socket.assigns.category, socket.assigns.page)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, review_error(reason))}
    end
  end

  def handle_event("reject", params, socket) do
    %{"proposal_id" => id, "rejection_reason" => reason} = proposal_params(params)

    case Extractions.review_proposal(socket.assigns.current_user.id, id, "rejected", %{
           rejection_reason: reason
         }) do
      {:ok, _proposal} ->
        {:noreply,
         socket
         |> put_flash(:info, "Proposal rejected.")
         |> load_proposals(socket.assigns.status, socket.assigns.category, socket.assigns.page)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, review_error(reason))}
    end
  end

  def handle_event("edit", params, socket) do
    %{
      "proposal_id" => id,
      "title" => title,
      "description" => description
    } = attrs = proposal_params(params)

    attrs = %{
      title: title,
      description: description,
      owner: blank_to_nil(attrs["owner"]),
      due_date: parse_date(attrs["due_date"])
    }

    case Extractions.review_proposal(socket.assigns.current_user.id, id, "edited", attrs) do
      {:ok, _proposal} ->
        {:noreply,
         socket
         |> put_flash(:info, "Proposal updated.")
         |> load_proposals(socket.assigns.status, socket.assigns.category, socket.assigns.page)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, review_error(reason))}
    end
  end

  defp load_proposals(socket, status, category, page) do
    result =
      Extractions.list_advisor_proposals(socket.assigns.current_user.id,
        status: status,
        category: category,
        page: page
      )

    proposals = Enum.map(result.entries, &prepare_proposal_forms/1)

    assign(socket,
      status: status,
      category: category,
      proposals: proposals,
      page: result.page,
      page_size: result.page_size,
      total_count: result.total_count,
      total_pages: result.total_pages,
      counts: Extractions.proposal_counts(socket.assigns.current_user.id)
    )
  end

  defp prepare_proposal_forms(proposal) do
    form_name = "proposal_#{proposal.id}"

    edit_form =
      to_form(
        %{
          proposal_id: proposal.id,
          title: proposal.title,
          description: proposal.description,
          owner: proposal.owner || "",
          due_date: if(proposal.due_date, do: Date.to_iso8601(proposal.due_date), else: "")
        },
        as: form_name
      )

    reject_form =
      to_form(%{proposal_id: proposal.id, rejection_reason: ""}, as: form_name)

    proposal
    |> Map.put(:edit_form, edit_form)
    |> Map.put(:reject_form, reject_form)
  end

  defp proposal_params(params) do
    Enum.find_value(params, %{}, fn
      {key, value} when is_binary(key) and is_map(value) ->
        if String.starts_with?(key, "proposal_"), do: value

      _ ->
        nil
    end)
  end

  defp parse_page(value) when is_integer(value), do: max(value, 1)

  defp parse_page(value) when is_binary(value) do
    case Integer.parse(value) do
      {page, ""} -> max(page, 1)
      _ -> 1
    end
  end

  defp parse_page(_), do: 1

  defp pagination_range(%{total_count: 0}), do: {0, 0}

  defp pagination_range(%{page: page, page_size: size, total_count: total}) do
    {(page - 1) * size + 1, min(page * size, total)}
  end

  defp page_numbers(total_pages), do: Enum.to_list(1..total_pages)

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp parse_date(""), do: nil
  defp parse_date(nil), do: nil

  defp parse_date(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp review_error(:not_found), do: "That proposal could not be found."
  defp review_error(:proposal_already_reviewed), do: "This proposal has already been reviewed."

  defp review_error(:rejection_reason_required),
    do: "Please provide a reason for rejecting this proposal."

  defp review_error(:meeting_context_not_found),
    do: "The meeting or client associated with this proposal could not be found."

  defp review_error(_), do: "We couldn't complete that review. Please try again."

  defp category_label("decision"), do: "Decision"
  defp category_label("action_item"), do: "Action item"
  defp category_label("commitment"), do: "Commitment"
  defp category_label("risk"), do: "Risk"
  defp category_label("unresolved_question"), do: "Unresolved question"
  defp category_label(value), do: value

  defp status_label("pending"), do: "Pending review"
  defp status_label("approved"), do: "Approved"
  defp status_label("rejected"), do: "Rejected"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.workspace flash={@flash} current_user={@current_user} active_page={@active_page}>
      <div class="mb-8">
        <p class="text-sm font-medium tracking-wide text-[#087C43]">FOLLOW-UP WORKFLOW</p>
        <h1 class="mt-2 text-2xl font-semibold tracking-tight text-[#17231C] sm:text-3xl">
          Actions & extracted findings
        </h1>
        <p class="mt-2 text-sm leading-6 text-[#68756C] sm:text-base">
          Review AI-generated findings, inspect their evidence and decide what becomes part of your client follow-up workflow.
        </p>
      </div>

      <div class="mb-6 grid grid-cols-1 gap-3 sm:grid-cols-3">
        <.count_card
          label="Pending review"
          value={Map.get(@counts, "pending", 0)}
          active={@status == "pending"}
        />
        <.count_card
          label="Approved"
          value={Map.get(@counts, "approved", 0)}
          active={@status == "approved"}
        />
        <.count_card
          label="Rejected"
          value={Map.get(@counts, "rejected", 0)}
          active={@status == "rejected"}
        />
      </div>

      <form
        phx-change="filter"
        class="mb-6 flex flex-col gap-3 rounded-xl border border-[#E5EBE6] bg-white p-4 sm:flex-row sm:items-center"
      >
        <label class="text-sm font-medium text-[#526057]" for="status-filter">Review status</label>
        <select
          id="status-filter"
          name="status"
          class="rounded-lg border border-[#DCE5DE] bg-white px-3 py-2 text-sm text-[#26352B]"
        >
          <option value="pending" selected={@status == "pending"}>Pending review</option>
          <option value="approved" selected={@status == "approved"}>Approved</option>
          <option value="rejected" selected={@status == "rejected"}>Rejected</option>
        </select>
        <label class="text-sm font-medium text-[#526057]" for="category-filter">Category</label>
        <select
          id="category-filter"
          name="category"
          class="rounded-lg border border-[#DCE5DE] bg-white px-3 py-2 text-sm text-[#26352B]"
        >
          <option :for={{label, value} <- @categories} value={value} selected={@category == value}>
            {label}
          </option>
        </select>
      </form>

      <div
        :if={@total_count > 0}
        class="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between"
      >
        <p class="text-sm text-[#68756C]">
          Showing {elem(pagination_range(assigns), 0)}–{elem(pagination_range(assigns), 1)} of {@total_count} proposals
        </p>
        <nav :if={@total_pages > 1} aria-label="Proposal pagination" class="flex items-center gap-1">
          <.button
            type="button"
            variant="secondary"
            phx-click="paginate"
            phx-value-page={@page - 1}
            disabled={@page == 1}
            class="w-auto px-3 py-2"
          >
            Previous
          </.button>
          <.button
            :for={page <- page_numbers(@total_pages)}
            type="button"
            variant={if(page == @page, do: "primary", else: "secondary")}
            phx-click="paginate"
            phx-value-page={page}
            aria-current={if page == @page, do: "page", else: "false"}
            class="w-auto min-w-9 px-3 py-2"
          >
            {page}
          </.button>
          <.button
            type="button"
            variant="secondary"
            phx-click="paginate"
            phx-value-page={@page + 1}
            disabled={@page == @total_pages}
            class="w-auto px-3 py-2"
          >
            Next
          </.button>
        </nav>
      </div>

      <div
        :if={@proposals == []}
        class="flex min-h-[280px] flex-col items-center justify-center rounded-2xl border border-dashed border-[#DCE5DE] bg-white px-6 py-12 text-center"
      >
        <div class="flex h-14 w-14 items-center justify-center rounded-2xl bg-[#EAF5EE] text-[#087C43]">
          <svg
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="1.7"
            class="h-7 w-7"
            aria-hidden="true"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M9 11l3 3L22 4M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"
            />
          </svg>
        </div>
        <h2 class="mt-5 text-lg font-semibold text-[#26352B]">No proposals to show</h2>
        <p class="mt-2 max-w-md text-sm leading-6 text-[#68756C]">
          {if @status == "pending",
            do: "New findings will appear here after transcript processing is complete.",
            else: "There are no proposals matching these filters."}
        </p>
      </div>

      <div :if={@proposals != []} class="space-y-4">
        <article
          :for={proposal <- @proposals}
          id={"proposal-#{proposal.id}"}
          class="overflow-hidden rounded-2xl border border-[#E5EBE6] bg-white"
        >
          <details class="group">
            <summary class="flex cursor-pointer list-none items-center justify-between gap-4 p-5 sm:p-6 [&::-webkit-details-marker]:hidden">
              <div class="min-w-0 flex-1">
                <div class="mb-2 flex flex-wrap items-center gap-2">
                  <span class="rounded-full bg-[#EAF5EE] px-2.5 py-1 text-xs font-medium text-[#087C43]">
                    {category_label(proposal.category)}
                  </span>
                  <span class="rounded-full bg-[#F0F4F1] px-2.5 py-1 text-xs font-medium text-[#526057]">
                    {status_label(proposal.status)}
                  </span>
                </div>
                <h2 class="text-base font-semibold text-[#26352B]">{proposal.title}</h2>
              </div>
              <svg
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="1.8"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="h-5 w-5 shrink-0 text-[#68756C] transition-transform group-open:rotate-180"
                aria-hidden="true"
              >
                <path d="m6 9 6 6 6-6" />
              </svg>
            </summary>

            <div class="border-t border-[#EEF2EF] p-5 sm:p-6">
              <div class="flex flex-wrap items-start justify-between gap-3">
                <div class="min-w-0 flex-1">
                  <p class="whitespace-pre-line text-sm leading-6 text-[#526057]">
                    {proposal.description}
                  </p>
                  <p class="mt-3 text-xs text-[#87938A]">
                    {proposal.processing_run.transcript.meeting.client.name}
                    <span class="px-1">·</span>
                    {proposal.processing_run.transcript.meeting.title}
                  </p>
                </div>
                <div :if={not is_nil(proposal.confidence)} class="shrink-0 text-right">
                  <p class="text-xs text-[#87938A]">AI confidence</p>
                  <p class="mt-1 text-sm font-semibold text-[#526057]">
                    {Decimal.round(proposal.confidence, 2) |> Decimal.to_string()}
                  </p>
                </div>
              </div>

              <div :if={proposal.categories != []} class="mt-4 flex flex-wrap gap-2">
                <span
                  :for={category <- proposal.categories -- [proposal.category]}
                  class="rounded-full border border-[#E5EBE6] px-2.5 py-1 text-xs text-[#68756C]"
                >
                  {category_label(category)}
                </span>
              </div>

              <details class="mt-5 border-t border-[#EEF2EF] pt-4">
                <summary class="cursor-pointer text-sm font-semibold text-[#087C43]">
                  View transcript evidence ({length(proposal.evidence_records)})
                </summary>
                <div class="mt-3 space-y-3">
                  <blockquote
                    :for={evidence <- proposal.evidence_records}
                    class="rounded-lg bg-[#F7F9F7] p-4 text-sm leading-6 text-[#526057]"
                  >
                    <p>{evidence.quote}</p>
                    <p class="mt-2 text-xs text-[#87938A]">
                      {evidence.speaker || "Speaker not identified"}
                      <span :if={evidence.timestamp} class="px-1">·</span>{evidence.timestamp}
                    </p>
                  </blockquote>
                  <p :if={proposal.evidence_records == []} class="text-sm text-[#87938A]">
                    No linked transcript segments are available for this proposal.
                  </p>
                </div>
              </details>

              <details :if={proposal.status == "pending"} class="mt-4 border-t border-[#EEF2EF] pt-4">
                <summary class="cursor-pointer text-sm font-semibold text-[#526057]">
                  Edit proposal
                </summary>
                <.form
                  for={proposal.edit_form}
                  id={"edit-proposal-#{proposal.id}"}
                  phx-submit="edit"
                  class="mt-4 grid gap-3"
                >
                  <input
                    type="hidden"
                    name={proposal.edit_form[:proposal_id].name}
                    value={proposal.id}
                  />
                  <.input field={proposal.edit_form[:title]} label="Title" required />
                  <.textarea
                    field={proposal.edit_form[:description]}
                    label="Description"
                    rows={3}
                    required
                  />
                  <div class="grid gap-3 sm:grid-cols-2">
                    <.input field={proposal.edit_form[:owner]} label="Owner" />
                    <.input field={proposal.edit_form[:due_date]} type="date" label="Due date" />
                  </div>
                  <div>
                    <.button type="submit" class="w-auto" loading_text="Saving changes...">
                      Save changes
                    </.button>
                  </div>
                </.form>
              </details>

              <div
                :if={proposal.status == "pending"}
                class="mt-5 flex flex-col gap-3 border-t border-[#EEF2EF] pt-4 sm:flex-row sm:items-end sm:justify-between"
              >
                <.form
                  for={proposal.reject_form}
                  id={"reject-proposal-#{proposal.id}"}
                  phx-submit="reject"
                  class="flex w-full min-w-0 flex-col gap-2 sm:flex-1 sm:flex-row sm:items-end"
                >
                  <input
                    type="hidden"
                    name={proposal.reject_form[:proposal_id].name}
                    value={proposal.id}
                  />
                  <div class="w-full min-w-0 sm:flex-1">
                    <.input
                      field={proposal.reject_form[:rejection_reason]}
                      placeholder="Reason for rejection"
                      required
                      class="!text-[#17231C] placeholder:!text-[#9AA69D]"
                    />
                  </div>
                  <.button
                    type="submit"
                    variant="secondary"
                    class="!w-full shrink-0 border-red-200 text-red-700 hover:bg-red-50 sm:!w-auto"
                    loading_text="Rejecting..."
                  >
                    Reject
                  </.button>
                </.form>
                <div class="w-full sm:w-auto sm:shrink-0">
                  <.button
                    type="button"
                    phx-click="approve"
                    phx-value-id={proposal.id}
                    class="!w-full sm:!w-auto"
                    loading_text="Approving..."
                  >
                    Approve proposal
                  </.button>
                </div>
              </div>

              <details :if={proposal.reviews != []} class="mt-4 border-t border-[#EEF2EF] pt-4">
                <summary class="cursor-pointer text-sm font-semibold text-[#526057]">
                  Review history ({length(proposal.reviews)})
                </summary>
                <div class="mt-3 space-y-3">
                  <div :for={review <- proposal.reviews} class="rounded-lg bg-[#F7F9F7] p-3">
                    <p class="text-sm font-medium text-[#26352B]">
                      {String.capitalize(review.action)}
                    </p>
                    <p :if={review.notes} class="mt-1 text-sm text-[#68756C]">{review.notes}</p>
                    <p class="mt-1 text-xs text-[#87938A]">
                      {Calendar.strftime(review.inserted_at, "%b %d, %Y at %H:%M UTC")}
                    </p>
                  </div>
                </div>
              </details>
            </div>
          </details>
        </article>
      </div>
    </Layouts.workspace>
    """
  end

  defp count_card(assigns) do
    ~H"""
    <div class={[
      "rounded-xl border bg-white p-4",
      @active && "border-[#A8D5B8] ring-1 ring-[#A8D5B8]",
      !@active && "border-[#E5EBE6]"
    ]}>
      <p class="text-sm text-[#68756C]">{@label}</p>
      <p class="mt-1 text-2xl font-semibold tabular-nums text-[#26352B]">{@value}</p>
    </div>
    """
  end
end
