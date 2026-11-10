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
