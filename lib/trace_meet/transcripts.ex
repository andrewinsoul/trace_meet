defmodule TraceMeet.Transcripts do
  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias TraceMeet.Repo
  alias TraceMeet.Meetings.Meeting
  alias TraceMeet.Transcripts.Transcript

  def list_transcripts(advisor_id, meeting_id) do
    from(t in Transcript,
      where: t.advisor_id == ^advisor_id and t.meeting_id == ^meeting_id,
      order_by: [desc: t.version]
    )
    |> Repo.all()
  end

  def get_selected_transcript(advisor_id, meeting_id) do
    Repo.one(
      from(t in Transcript,
        where:
          t.advisor_id == ^advisor_id and t.meeting_id == ^meeting_id and
            not is_nil(t.selected_at),
        limit: 1
      )
    )
  end

  def create_transcript(advisor_id, meeting_id, attrs) do
    Multi.new()
    |> Multi.run(:meeting, fn repo, _changes ->
      meeting =
        repo.one(
          from(m in Meeting,
            where: m.id == ^meeting_id and m.user_id == ^advisor_id and is_nil(m.archived_at),
            lock: "FOR UPDATE"
          )
        )

      case meeting do
        %Meeting{status: "completed"} -> {:ok, meeting}
        %Meeting{} -> {:error, :meeting_not_completed}
        nil -> {:error, :not_found}
      end
    end)
    |> Multi.run(:transcript, fn repo, %{meeting: meeting} ->
      version =
        repo.one(
          from(t in Transcript,
            where: t.meeting_id == ^meeting.id,
            select: coalesce(max(t.version), 0)
          )
        ) + 1

      repo.update_all(
        from(t in Transcript,
          where: t.meeting_id == ^meeting.id and t.advisor_id == ^advisor_id
        ),
        set: [selected_at: nil]
      )

      %Transcript{meeting_id: meeting.id, advisor_id: advisor_id, version: version}
      |> Transcript.changeset(attrs)
      |> Ecto.Changeset.put_change(:selected_at, DateTime.utc_now())
      |> repo.insert()
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{transcript: transcript}} -> {:ok, transcript}
      {:error, _operation, reason, _changes} -> {:error, reason}
    end
  end

  def select_transcript(advisor_id, meeting_id, transcript_id) do
    with %Meeting{status: "completed"} <- get_owned_meeting(advisor_id, meeting_id),
         %Transcript{} = transcript <- get_transcript(advisor_id, meeting_id, transcript_id) do
      Multi.new()
      |> Multi.update_all(
        :clear_selection,
        from(t in Transcript,
          where: t.meeting_id == ^meeting_id and t.advisor_id == ^advisor_id
        ),
        set: [selected_at: nil]
      )
      |> Multi.update(:select, Ecto.Changeset.change(transcript, selected_at: DateTime.utc_now()))
      |> Repo.transaction()
      |> case do
        {:ok, %{select: selected}} -> {:ok, selected}
        {:error, _operation, reason, _changes} -> {:error, reason}
      end
    else
      nil -> {:error, :not_found}
      %Meeting{} -> {:error, :meeting_not_completed}
    end
  end

  defp get_owned_meeting(advisor_id, meeting_id) do
    Repo.one(from(m in Meeting, where: m.id == ^meeting_id and m.user_id == ^advisor_id))
  end

  defp get_transcript(advisor_id, meeting_id, transcript_id) do
    Repo.one(
      from(t in Transcript,
        where:
          t.id == ^transcript_id and t.meeting_id == ^meeting_id and
            t.advisor_id == ^advisor_id
      )
    )
  end
end
