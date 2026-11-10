defmodule TraceMeetWeb.MeetingLive.Show do
  use TraceMeetWeb, :live_view

  alias TraceMeet.Meetings
  alias TraceMeet.ProcessingRuns
  alias TraceMeet.Transcripts
  alias TraceMeet.Transcripts.FileExtractor

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Meetings.get_meeting(socket.assigns.current_user.id, id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "That meeting could not be found.")
         |> push_navigate(to: ~p"/meetings")}

      meeting ->
        advisor_id = socket.assigns.current_user.id
        selected_transcript = Transcripts.get_selected_transcript(advisor_id, meeting.id)

        processing_runs =
          if selected_transcript do
            ProcessingRuns.list_for_transcript(advisor_id, selected_transcript.id)
          else
            []
          end

        if connected?(socket) do
          Phoenix.PubSub.subscribe(TraceMeet.PubSub, "advisor:#{advisor_id}:processing")
        end

        {:ok,
         socket
         |> assign(
           meeting: meeting,
           page_title: meeting.title,
           transcripts: Transcripts.list_transcripts(advisor_id, meeting.id),
           selected_transcript: selected_transcript,
           processing_runs: processing_runs,
           show_default_prompt_modal: false
         )
         |> allow_upload(:transcript_upload,
           accept: ~w(.txt .md .pdf .docx),
           max_entries: 1,
           max_file_size: 2_000_000
         )}
    end
  end

  @impl true
  def handle_event("archive", _params, socket) do
    case Meetings.archive_meeting(socket.assigns.current_user.id, socket.assigns.meeting.id) do
      {:ok, _meeting} ->
        {:noreply,
         socket
         |> put_flash(:info, "Meeting archived.")
         |> push_navigate(to: ~p"/meetings")}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "That meeting could not be found.")
         |> push_navigate(to: ~p"/meetings")}
    end
  end

  @impl true
  def handle_event("save_transcript", %{"transcript" => %{"content" => content}}, socket) do
    save_transcript(socket, %{"source_type" => "paste", "content" => content})
  end

  def handle_event("validate_transcript_upload", _params, socket), do: {:noreply, socket}

  def handle_event("upload_transcript", _params, socket) do
    case consume_uploaded_entries(socket, :transcript_upload, fn %{path: path}, entry ->
           case FileExtractor.extract(path, entry.client_name) do
             {:ok, content} ->
               {:ok,
                %{
                  "source_type" => "file",
                  "original_filename" => entry.client_name,
                  "content" => content
                }}

             {:error, reason} ->
               {:ok, {:error, reason}}
           end
         end) do
      [%{} = attrs] ->
        save_transcript(socket, attrs)

      [{:error, reason}] ->
        {:noreply, put_flash(socket, :error, upload_transcript_error(reason))}

      [] ->
        {:noreply, put_flash(socket, :error, "Choose a valid transcript file first.")}

      _ ->
        {:noreply, put_flash(socket, :error, "The transcript file could not be read.")}
    end
  end

  def handle_event("select_transcript", %{"id" => transcript_id}, socket) do
    case Transcripts.select_transcript(
           socket.assigns.current_user.id,
           socket.assigns.meeting.id,
           transcript_id
         ) do
      {:ok, _transcript} ->
        {:noreply,
         socket
         |> refresh_transcripts()
         |> put_flash(:info, "Transcript version selected.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, transcript_error(reason))}
    end
  end

  def handle_event("close_default_prompt_modal", _params, socket) do
    {:noreply, assign(socket, :show_default_prompt_modal, false)}
  end

  def handle_event("create_default_prompt", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/ai-configuration?new=true")}
  end

  def handle_event("process_transcript", _params, socket) do
    advisor_id = socket.assigns.current_user.id
    meeting_id = socket.assigns.meeting.id

    case socket.assigns.selected_transcript do
      nil ->
        {:noreply, put_flash(socket, :error, "Select a transcript version before processing.")}

      transcript ->
        case ProcessingRuns.enqueue(advisor_id, meeting_id, transcript.id) do
          {:ok, _run} ->
            {:noreply,
             socket
             |> refresh_transcripts()
             |> put_flash(:info, "Transcript processing has been queued.")}

          {:error, :default_prompt_required} ->
            {:noreply, assign(socket, :show_default_prompt_modal, true)}

          {:error, :already_processing} ->
            {:noreply,
             socket
             |> refresh_transcripts()
             |> put_flash(:info, "This transcript already has an active processing run.")}

          {:error, :transcript_not_selected} ->
            {:noreply,
             socket
             |> refresh_transcripts()
             |> put_flash(:error, "Select this transcript version before processing.")}

          {:error, _reason} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               "We couldn't queue transcript processing. Please try again."
             )}
        end
    end
  end

  @impl true
  def handle_info({:processing_run_updated, transcript_id}, socket) do
    case socket.assigns.selected_transcript do
      %{id: ^transcript_id} ->
        previous_runs = socket.assigns.processing_runs
        socket = refresh_transcripts(socket)

        case completed_status_change(previous_runs, socket.assigns.processing_runs) do
          :completed ->
            {:noreply, put_flash(socket, :info, "Transcript processing completed successfully.")}

          :failed ->
            {:noreply, put_flash(socket, :error, "Transcript processing failed. You can start a new run.")}

          _ ->
            {:noreply, socket}
        end

      _ ->
        {:noreply, socket}
    end
  end

  defp completed_status_change(previous_runs, current_runs) do
    Enum.find_value(current_runs, fn current ->
      previous = Enum.find(previous_runs, &(&1.id == current.id))

      case {previous && previous.status, current.status} do
        {status, "completed"} when status in ["queued", "processing"] -> :completed
        {status, "failed"} when status in ["queued", "processing"] -> :failed
        _ -> nil
      end
    end)
  end

  defp save_transcript(socket, attrs) do
    case Transcripts.create_transcript(
           socket.assigns.current_user.id,
           socket.assigns.meeting.id,
           attrs
         ) do
      {:ok, _transcript} ->
        {:noreply,
         socket
         |> refresh_transcripts()
         |> put_flash(:info, "Transcript saved. The new version is now selected.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, transcript_error(reason))}
    end
  end

  defp refresh_transcripts(socket) do
    advisor_id = socket.assigns.current_user.id
    meeting_id = socket.assigns.meeting.id

    selected_transcript = Transcripts.get_selected_transcript(advisor_id, meeting_id)

    assign(socket,
      transcripts: Transcripts.list_transcripts(advisor_id, meeting_id),
      selected_transcript: selected_transcript,
      processing_runs:
        if(selected_transcript,
          do: ProcessingRuns.list_for_transcript(advisor_id, selected_transcript.id),
          else: []
        )
    )
  end

  defp transcript_error(:meeting_not_completed),
    do: "Transcripts can only be added to completed meetings."

  defp transcript_error(:not_found), do: "That meeting or transcript could not be found."

  defp transcript_error(_reason),
    do: "The transcript could not be saved. Check the content and try again."

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.workspace flash={@flash} current_user={@current_user} active_page={:meetings}>
      <div class="mx-auto max-w-4xl">
        <div class="mb-8">
          <.link
            navigate={~p"/meetings"}
            class="text-sm font-medium text-[#68756C] hover:text-[#087C43]"
          >
            ← Back to meetings
          </.link>
        </div>

        <section class="w-full overflow-hidden rounded-2xl border border-[#E5EBE6] bg-white shadow-sm">
          <div class="flex flex-col gap-5 border-b border-[#EEF2EF] p-5 sm:flex-row sm:items-start sm:justify-between sm:p-8">
            <div class="min-w-0">
              <p class="text-xs font-semibold uppercase tracking-wide text-[#087C43]">
                MEETING RECORD
              </p>
              <h1 class="mt-2 text-2xl font-semibold tracking-tight text-[#17231C]">
                {@meeting.title}
              </h1>
              <p class="mt-2 text-sm text-[#68756C]">
                Client:
                <.link
                  navigate={~p"/clients/#{@meeting.client_id}"}
                  class="font-semibold text-[#087C43] hover:underline"
                >
                  {@meeting.client.name}
                </.link>
              </p>
            </div>
            <div class="flex flex-wrap gap-2">
              <.link
                navigate={~p"/meetings/#{@meeting.id}/edit"}
                class="inline-flex items-center justify-center rounded-lg border border-[#DCE5DE] bg-white px-3.5 py-2 text-sm font-semibold text-[#526057] transition hover:bg-[#F5F8F5]"
              >
                Edit meeting
              </.link>
              <button
                type="button"
                phx-click="archive"
                phx-confirm="Archive this meeting? It will be removed from your active meeting list."
                class="inline-flex items-center justify-center rounded-lg border border-[#F0D7D4] bg-white px-3.5 py-2 text-sm font-semibold text-[#A33B32] transition hover:bg-[#FFF7F6]"
              >
                Archive
              </button>
            </div>
          </div>

          <div class="grid gap-8 p-5 sm:grid-cols-2 sm:p-8">
            <div>
              <p class="text-xs font-semibold uppercase tracking-wide text-[#87938A]">Status</p>
              <p class="mt-2 text-sm font-medium text-[#26352B]">{status_label(@meeting.status)}</p>
            </div>
            <div>
              <p class="text-xs font-semibold uppercase tracking-wide text-[#87938A]">
                Meeting date and time
              </p>
              <p class="mt-2 text-sm text-[#26352B]">{meeting_time(@meeting)}</p>
            </div>
            <div class="sm:col-span-2">
              <p class="text-xs font-semibold uppercase tracking-wide text-[#87938A]">
                Agenda or notes
              </p>
              <p class="mt-2 whitespace-pre-wrap text-sm leading-6 text-[#526057]">
                {description(@meeting.description)}
              </p>
            </div>
          </div>

          <div class="border-t border-[#EEF2EF] bg-[#FBFCFB] px-5 py-6 sm:px-8">
            <div class="flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between">
              <div>
                <h2 class="text-sm font-semibold text-[#26352B]">Transcripts</h2>
                <p class="mt-1 max-w-2xl text-xs leading-5 text-[#68756C]">
                  Add a transcript by pasting text or uploading a TXT, Markdown, PDF, or DOCX file. Each upload creates a new version; the latest version is selected automatically and previous versions are preserved.
                </p>
              </div>
              <span class="inline-flex w-fit rounded-full bg-[#F1F4F1] px-3 py-1 text-xs font-medium text-[#68756C]">
                {length(@transcripts)} {if length(@transcripts) == 1, do: "version", else: "versions"}
              </span>
            </div>

            <%= if @meeting.status == "completed" do %>
              <details class="mt-5 rounded-xl border border-[#E5EBE6] bg-white">
                <summary class="flex cursor-pointer list-none items-center justify-between gap-3 px-4 py-3 text-sm font-semibold text-[#26352B] marker:hidden">
                  <span>Add transcript</span>
                  <span class="flex items-center gap-2 text-xs font-medium text-[#87938A]">
                    Paste or upload <span aria-hidden="true">⌄</span>
                  </span>
                </summary>
                <div class="border-t border-[#EEF2EF] p-4">
                  <div class="grid gap-6 lg:grid-cols-2">
                <.form
                  for={%{}}
                  as={:transcript}
                  id="transcript-paste-form"
                  phx-submit="save_transcript"
                  class="space-y-3"
                >
                  <label for="transcript-content" class="block text-sm font-medium text-[#26352B]">
                    Paste transcript
                  </label>
                  <textarea
                    id="transcript-content"
                    name="transcript[content]"
                    rows="8"
                    required
                    maxlength="2000000"
                    placeholder="Paste the meeting transcript here..."
                    class="w-full rounded-xl border border-[#DCE5DE] bg-white px-3 py-3 text-sm text-[#26352B] outline-none transition placeholder:text-[#A0AAA3] focus:border-[#087C43] focus:ring-2 focus:ring-[#087C43]/10"
                  ></textarea>
                  <button
                    type="submit"
                    class="inline-flex items-center rounded-lg bg-[#087C43] px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-[#066A39]"
                  >
                    Save transcript
                  </button>
                </.form>

                <div class="space-y-3">
                  <p class="text-sm font-medium text-[#26352B]">Upload transcript file</p>
                  <.form
                    for={%{}}
                    id="transcript-upload-form"
                    phx-submit="upload_transcript"
                    phx-change="validate_transcript_upload"
                    class="rounded-xl border border-dashed border-[#C9D7CC] bg-white p-4"
                  >
                    <.live_file_input
                      upload={@uploads.transcript_upload}
                      class="block w-full text-sm text-[#526057] file:mr-3 file:rounded-lg file:border-0 file:bg-[#EAF5EE] file:px-3 file:py-2 file:text-sm file:font-semibold file:text-[#087C43]"
                    />
                    <p class="mt-2 text-xs text-[#87938A]">
                      TXT, Markdown, PDF, or DOCX, up to 2 MB.
                    </p>
                    <%= for entry <- @uploads.transcript_upload.entries do %>
                      <p class="mt-2 truncate text-xs text-[#526057]">{entry.client_name}</p>
                      <%= for err <- upload_errors(@uploads.transcript_upload, entry) do %>
                        <p class="mt-1 text-xs text-red-600">{upload_error(err)}</p>
                      <% end %>
                    <% end %>
                    <button
                      type="submit"
                      class="mt-4 inline-flex items-center rounded-lg border border-[#DCE5DE] bg-white px-4 py-2.5 text-sm font-semibold text-[#26352B] transition hover:bg-[#F5F8F5]"
                    >
                      Upload version
                    </button>
                  </.form>
                </div>
                  </div>
                </div>
              </details>
            <% else %>
              <p class="mt-5 rounded-xl border border-[#F0E4C9] bg-[#FFFBF1] px-4 py-3 text-sm text-[#80652E]">
                Transcript submission is available after this meeting is marked completed.
              </p>
            <% end %>

            <%= if @selected_transcript do %>
              <div class="mt-6 rounded-xl border border-[#BBDCC7] bg-[#F2FAF4] p-4">
                <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                  <div class="min-w-0">
                    <p class="text-xs font-semibold uppercase tracking-wide text-[#087C43]">
                      Selected transcript · Version {@selected_transcript.version}
                    </p>
                    <p class="mt-1 text-xs text-[#526057]">{transcript_source(@selected_transcript)}</p>
                    <p class="mt-2 max-w-2xl text-xs leading-5 text-[#526057]">
                      Prepare this transcript to identify decisions, action items, commitments, risks, blockers, and unresolved questions for your review.
                    </p>
                  </div>
                  <%= if active_processing_run(@processing_runs) do %>
                    <span class="inline-flex shrink-0 items-center rounded-lg bg-[#EAF5EE] px-4 py-2.5 text-sm font-semibold text-[#087C43]">
                      {processing_status(active_processing_run(@processing_runs).status)}
                    </span>
                  <% else %>
                    <button
                      type="button"
                      phx-click="process_transcript"
                      phx-disable-with="Queueing..."
                      class="inline-flex shrink-0 items-center justify-center rounded-lg bg-[#087C43] px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-[#066A39]"
                    >
                      Process transcript
                    </button>
                  <% end %>
                </div>
              </div>
            <% end %>

            <%= if latest_completed_run(@processing_runs) do %>
              <details class="mt-4 rounded-xl border border-[#E5EBE6] bg-white">
                <summary class="flex cursor-pointer list-none items-center justify-between gap-3 px-4 py-3 text-sm font-semibold text-[#26352B] marker:hidden">
                  <span>Cleaned transcript</span>
                  <span class="flex items-center gap-2 text-xs font-medium text-[#87938A]">
                    Latest completed run <span aria-hidden="true">⌄</span>
                  </span>
                </summary>
                <div class="border-t border-[#EEF2EF] p-4">
                  <p class="text-xs text-[#68756C]">
                    This output belongs to its processing run. Earlier runs and their outputs remain available in processing history.
                  </p>
                  <pre class="mt-3 max-h-96 overflow-auto whitespace-pre-wrap text-xs leading-5 text-[#526057]">{cleaned_preview(latest_completed_run(@processing_runs).cleaned_content)}</pre>
                </div>
              </details>
            <% end %>

            <%= if @processing_runs != [] do %>
              <details class="mt-4 rounded-xl border border-[#E5EBE6] bg-white">
                <summary class="flex cursor-pointer list-none items-center justify-between gap-3 px-4 py-3 text-sm font-semibold text-[#26352B] marker:hidden">
                  <span>Processing history ({length(@processing_runs)})</span>
                  <span class="flex items-center gap-2 text-xs font-medium text-[#87938A]">
                    Prompt and model details <span aria-hidden="true">⌄</span>
                  </span>
                </summary>
                <div class="space-y-3 border-t border-[#EEF2EF] p-4">
                  <%= for run <- @processing_runs do %>
                    <div class="flex items-center justify-between gap-3 text-xs">
                      <span class="text-[#526057]">
                        Run created {Calendar.strftime(run.inserted_at, "%b %d, %Y %I:%M %p UTC")}
                      </span>
                      <span class="font-semibold text-[#26352B]">{processing_status(run.status)}</span>
                    </div>
                    <p class="text-[11px] text-[#87938A]">
                      Prompt {run.prompt_version} · Model {run.model}
                    </p>
                    <%= if run.status == "failed" and run.error_message do %>
                      <p class="text-xs text-[#A33B32]">
                        Processing failed. You can start a new run for this transcript.
                      </p>
                    <% end %>
                  <% end %>
                </div>
              </details>
            <% end %>

            <%= if @transcripts != [] do %>
              <details class="mt-4 rounded-xl border border-[#E5EBE6] bg-white">
                <summary class="flex cursor-pointer list-none items-center justify-between gap-3 px-4 py-3 text-sm font-semibold text-[#26352B] marker:hidden">
                  <span>Transcript versions ({length(@transcripts)})</span>
                  <span class="flex items-center gap-2 text-xs font-medium text-[#87938A]">
                    Select another version <span aria-hidden="true">⌄</span>
                  </span>
                </summary>
                <div class="divide-y divide-[#EEF2EF] border-t border-[#EEF2EF]">
                <%= for transcript <- @transcripts do %>
                  <div class="flex flex-col gap-3 px-4 py-3 sm:flex-row sm:items-center sm:justify-between">
                    <div>
                      <p class="text-sm font-medium text-[#26352B]">Version {transcript.version}</p>
                      <p class="mt-1 text-xs text-[#87938A]">
                        {transcript_source(transcript)} · Added {Calendar.strftime(
                          transcript.inserted_at,
                          "%b %d, %Y %I:%M %p UTC"
                        )}
                      </p>
                    </div>
                    <%= if is_nil(transcript.selected_at) do %>
                      <button
                        type="button"
                        phx-click="select_transcript"
                        phx-value-id={transcript.id}
                        class="inline-flex w-fit items-center rounded-lg border border-[#DCE5DE] px-3 py-2 text-xs font-semibold text-[#526057] transition hover:bg-[#F5F8F5]"
                      >
                        Select version
                      </button>
                    <% else %>
                      <span class="text-xs font-semibold text-[#087C43]">Currently selected</span>
                    <% end %>
                  </div>
                <% end %>
                </div>
              </details>
            <% end %>
          </div>
        </section>
      </div>
      <div
        :if={@show_default_prompt_modal}
        class="fixed inset-0 z-50 flex items-center justify-center bg-[#17231C]/50 p-4"
        phx-window-keydown="close_default_prompt_modal"
        phx-key="escape"
      >
        <section
          role="dialog"
          aria-modal="true"
          aria-labelledby="default-prompt-title"
          class="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl"
        >
          <div class="flex h-11 w-11 items-center justify-center rounded-full bg-[#EAF5EE] text-[#087C43]">
            <span aria-hidden="true">✦</span>
          </div>
          <h2 id="default-prompt-title" class="mt-4 text-lg font-semibold text-[#26352B]">
            No default prompt configuration
          </h2>
          <p class="mt-2 text-sm leading-6 text-[#68756C]">
            You haven't configured a default AI prompt yet. TraceMeet needs one to tailor transcript analysis to your advisory practice.
          </p>
          <div class="mt-6 flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
            <button
              type="button"
              phx-click="close_default_prompt_modal"
              class="rounded-lg border border-[#DCE5DE] px-4 py-2.5 text-sm font-semibold text-[#526057]"
            >
              Cancel
            </button>
            <button
              type="button"
              phx-click="create_default_prompt"
              class="rounded-lg bg-[#087C43] px-4 py-2.5 text-sm font-semibold text-white hover:bg-[#066A39]"
            >
              Create prompt configuration
            </button>
          </div>
        </section>
      </div>
    </Layouts.workspace>
    """
  end

  defp transcript_source(%{source_type: "file", original_filename: name}),
    do: name || "Uploaded file"

  defp transcript_source(_transcript), do: "Pasted text"

  defp cleaned_preview(content) when is_binary(content) do
    if String.length(content) > 3_000 do
      String.slice(content, 0, 3_000) <> "\n\n…"
    else
      content
    end
  end

  defp active_processing_run(runs) do
    Enum.find(runs, &(&1.status in ["queued", "processing"]))
  end

  defp latest_completed_run(runs) do
    Enum.find(runs, &(&1.status == "completed" and is_binary(&1.cleaned_content)))
  end

  defp processing_status("queued"), do: "Queued"
  defp processing_status("processing"), do: "Processing"
  defp processing_status("completed"), do: "Completed"
  defp processing_status("failed"), do: "Failed"
  defp processing_status("cancelled"), do: "Cancelled"

  defp upload_error(:too_large), do: "The file is larger than the 2 MB upload limit."
  defp upload_error(:not_accepted), do: "Choose a TXT, Markdown, PDF, or DOCX file."
  defp upload_error(_), do: "The file could not be uploaded. Please try another file."

  defp upload_transcript_error(:file_too_large),
    do: "This file exceeds the 2 MB upload limit."

  defp upload_transcript_error(:file_unreadable),
    do: "We couldn't access this file. Please try uploading it again."

  defp upload_transcript_error(:unsupported_file_type),
    do: "This file type isn't supported. Upload a TXT, Markdown, PDF, or DOCX file."

  defp upload_transcript_error(:no_extractable_text),
    do: "We couldn't find readable text in this file. Scanned PDFs and image-only documents aren't supported yet."

  defp upload_transcript_error(:extracted_text_too_large),
    do: "The extracted transcript exceeds the 2 MB text limit. Please upload a shorter document."

  defp upload_transcript_error(:docx_content_too_large),
    do: "This Word document contains too much expanded document data to process safely."

  defp upload_transcript_error(:invalid_docx),
    do: "We couldn't read this Word document. Make sure it is a valid, unprotected DOCX file."

  defp upload_transcript_error(:pdf_could_not_be_read),
    do: "We couldn't read this PDF. It may be damaged, password-protected, or use an unsupported format."

  defp upload_transcript_error(:invalid_text_encoding),
    do: "This file contains text in an unsupported encoding. Please save it as UTF-8 and try again."

  defp upload_transcript_error(_reason),
    do: "We couldn't extract text from this file. It may be damaged or use unsupported document features."

  defp status_label("in_progress"), do: "In progress"
  defp status_label(status), do: status |> String.replace("_", " ") |> String.capitalize()

  defp meeting_time(%{status: "scheduled", scheduled_at: %DateTime{} = value} = meeting),
    do: format_meeting_time(value, meeting.time_zone)

  defp meeting_time(%{started_at: %DateTime{} = value} = meeting),
    do: format_meeting_time(value, meeting.time_zone)

  defp meeting_time(_meeting), do: "Not provided"

  defp format_meeting_time(value, time_zone) do
    case DateTime.shift_zone(value, time_zone || "Etc/UTC", Tzdata.TimeZoneDatabase) do
      {:ok, local_value} -> Calendar.strftime(local_value, "%B %d, %Y at %I:%M %p")
      _ -> Calendar.strftime(value, "%B %d, %Y at %I:%M %p UTC")
    end
  end

  defp description(value) when is_binary(value) do
    case String.trim(value) do
      "" -> "No agenda or notes have been added."
      text -> text
    end
  end

  defp description(_), do: "No agenda or notes have been added."
end
