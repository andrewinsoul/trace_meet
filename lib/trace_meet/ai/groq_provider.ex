defmodule TraceMeet.AI.GroqProvider do
  @endpoint "https://api.groq.com/openai/v1/chat/completions"



  def clean_transcript(content, %{system_prompt: system_prompt}, model)
      when is_binary(content) and is_binary(system_prompt) and is_binary(model) do
    with {:ok, api_key} <- api_key(),
         {:ok, response} <- request(api_key, model, content, system_prompt),
         {:ok, result} <- decode_response(response),
         {:ok, result} <- validate_result(result, content) do
      {:ok, result}
    end
  end


  def extract_chunk(content, %{system_prompt: system_prompt, guardrails_snapshot: _guardrails}, model)
      when is_binary(content) and is_binary(system_prompt) and is_binary(model) do
    system = """
    #{system_prompt}

    Extract findings using these category values: decision, action_item, commitment, risk, unresolved_question.
    Return only facts supported by the text. Never invent owners or deadlines; use null when unknown.
    Every item must include categories (array), description, owner, deadline (YYYY-MM-DD or null), confidence (0..1 or null), uncertainties (array), and evidence_quotes (array of exact short quotes).
    An item may have multiple categories when genuinely appropriate. Do not duplicate the same underlying obligation.
    """

    with {:ok, result} <- request_json(model, system, content, 240_000),
         %{"items" => items} when is_list(items) <- result,
         :ok <- validate_items(items),
         :ok <- validate_evidence(items) do
      {:ok, %{items: Enum.map(items, &normalize_item/1)}}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_extraction_response}
    end
  end

  def consolidate(extractions, %{system_prompt: system_prompt, guardrails_snapshot: _guardrails}, model)
      when is_list(extractions) and is_binary(system_prompt) and is_binary(model) do
    system = """
    #{system_prompt}

    Consolidate the supplied chunk extraction items into distinct meeting-level proposals.
    Merge only items describing the same underlying fact or obligation. Combine complementary details and all supporting evidence quotes.
    Preserve conflicting statements and uncertainty; do not silently choose between contradictory deadlines or decisions.
    Return proposals with categories, description, owner, deadline, confidence, uncertainties, evidence_quotes, and source_extraction_indexes.
    source_extraction_indexes must refer to zero-based indexes in the supplied flat extraction list. Include at least one index per proposal. Do not invent indexes.
    """

    payload = Jason.encode!(%{extractions: extractions})

    with {:ok, result} <- request_json(model, system, payload, 240_000),
         %{"proposals" => proposals} when is_list(proposals) <- result,
         :ok <- validate_items(proposals),
         :ok <- validate_proposal_sources(proposals) do
      {:ok, %{proposals: Enum.map(proposals, &normalize_item/1)}}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_consolidation_response}
    end
  end

  defp request_json(model, system_prompt, user_content, timeout) do
    with {:ok, key} <- api_key() do
      body = %{
        model: model,
        messages: [
          %{role: "system", content: system_prompt},
          %{role: "user", content: user_content}
        ],
        response_format: %{type: "json_object"}
      }

      case Req.post(@endpoint, json: body, headers: [{"authorization", "Bearer #{key}"}], receive_timeout: timeout, retry: false) do
        {:ok, %Req.Response{status: status, body: response}} when status in 200..299 -> decode_response(response)
        {:ok, %Req.Response{status: status, body: response}} -> {:error, {:groq_http_error, status, error_message(response)}}
        {:error, reason} -> {:error, {:groq_request_failed, reason}}
      end
    end
  end

  defp validate_items(items) do
    allowed = ["decision", "action_item", "commitment", "risk", "unresolved_question"]

    valid = Enum.all?(items, fn item ->
      is_map(item) and is_binary(item["description"]) and item["description"] != "" and
        is_list(item["categories"]) and item["categories"] != [] and
        Enum.all?(item["categories"], &(&1 in allowed)) and
        (is_nil(item["owner"]) or is_binary(item["owner"])) and
        (is_nil(item["deadline"]) or valid_date?(item["deadline"])) and
        (is_nil(item["confidence"]) or (is_number(item["confidence"]) and item["confidence"] >= 0 and item["confidence"] <= 1)) and
        is_list(item["uncertainties"] || []) and
        is_list(item["evidence_quotes"] || [])
    end)

    if valid, do: :ok, else: {:error, :invalid_extraction_item}
  end


  defp validate_evidence(items) do
    if Enum.all?(items, fn item -> item["evidence_quotes"] != [] end),
      do: :ok,
      else: {:error, :extraction_evidence_required}
  end

  defp validate_proposal_sources(proposals) do
    if Enum.all?(proposals, fn item ->
         is_list(item["source_extraction_indexes"]) and item["source_extraction_indexes"] != [] and
           Enum.all?(item["source_extraction_indexes"], &is_integer/1)
       end),
      do: :ok,
      else: {:error, :consolidation_sources_required}
  end

  defp normalize_item(item) do
    %{
      categories: item["categories"], description: item["description"],
      owner: item["owner"], deadline: parse_deadline(item["deadline"]),
      confidence: item["confidence"], uncertainties: %{"items" => item["uncertainties"] || []},
      evidence_quotes: item["evidence_quotes"] || [],
      source_extraction_indexes: item["source_extraction_indexes"] || []
    }
  end

  defp valid_date?(value) when is_binary(value), do: match?({:ok, _}, Date.from_iso8601(value))
  defp valid_date?(_), do: false

  defp parse_deadline(nil), do: nil
  defp parse_deadline(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _ -> nil
    end
  end
  defp parse_deadline(_), do: nil

  defp api_key do
    case System.get_env("GROQ_API_KEY") do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, :missing_groq_api_key}
    end
  end

  defp request(api_key, model, content, system_prompt) do
    schema = %{
      type: "object",
      properties: %{
        cleaned_content: %{type: "string"},
        segments: %{
          type: "array",
          items: %{
            type: "object",
            properties: %{
              source_quote: %{type: "string"},
              cleaned_text: %{type: "string"}
            },
            required: ["source_quote", "cleaned_text"],
            additionalProperties: false
          }
        }
      },
      required: ["cleaned_content", "segments"],
      additionalProperties: false
    }

    body = %{
      model: model,
      messages: [
        %{role: "system", content: system_prompt},
        %{role: "user", content: "Clean this transcript:\n\n" <> content}
      ],
      response_format: %{
        type: "json_schema",
        json_schema: %{
          name: "cleaned_transcript",
          strict: true,
          schema: schema
        }
      }
    }

    case Req.post(@endpoint,
           json: body,
           headers: [{"authorization", "Bearer #{api_key}"}],
           receive_timeout: 240_000,
           retry: false
         ) do
      {:ok, %Req.Response{status: status, body: response}} when status in 200..299 ->
        {:ok, response}

      {:ok, %Req.Response{status: status, body: response}} ->
        {:error, {:groq_http_error, status, error_message(response)}}

      {:error, reason} ->
        {:error, {:groq_request_failed, reason}}
    end
  end

  defp decode_response(%{"choices" => [%{"message" => %{"content" => content}} | _]})
       when is_binary(content) do
    case Jason.decode(content) do
      {:ok, result} when is_map(result) -> {:ok, result}
      _ -> {:error, :invalid_ai_response}
    end
  end

  defp decode_response(_), do: {:error, :invalid_ai_response}

  defp validate_result(
         %{"cleaned_content" => cleaned, "segments" => segments},
         original
       )
       when is_binary(cleaned) and is_list(segments) and segments != [] and cleaned != "" do
    valid_segments =
      Enum.all?(segments, fn
        %{"source_quote" => quote, "cleaned_text" => text}
        when is_binary(quote) and is_binary(text) and quote != "" ->
          String.contains?(original, quote)

        _ ->
          false
      end)

    if valid_segments do
      {:ok,
       %{
         cleaned_content: cleaned,
         segments:
           Enum.map(segments, fn segment ->
             %{
               source_quote: segment["source_quote"],
               cleaned_text: segment["cleaned_text"]
             }
           end)
       }}
    else
      {:error, :invalid_cleaned_segments}
    end
  end

  defp validate_result(_, _), do: {:error, :invalid_cleaned_transcript}

  defp error_message(%{"error" => %{"message" => message}}) when is_binary(message),
    do: message

  defp error_message(_), do: "The provider rejected the request."
end
