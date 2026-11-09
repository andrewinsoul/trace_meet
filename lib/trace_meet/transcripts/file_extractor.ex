defmodule TraceMeet.Transcripts.FileExtractor do
  @max_file_size 2_000_000
  @max_content_size 2_000_000
  @max_docx_xml_size 10_000_000

  def extract(path, filename) do
    extension = filename |> Path.extname() |> String.downcase()

    with :ok <- validate_file_size(path),
         {:ok, content} <- extract_content(path, extension),
         true <- is_binary(content) and String.valid?(content),
         content <- String.trim(content),
         :ok <- validate_content(content) do
      {:ok, content}
    else
      false -> {:error, :invalid_text_encoding}
      {:error, reason} -> {:error, reason}
    end
  rescue
    _error -> {:error, :invalid_or_unsupported_document}
  catch
    :exit, _reason -> {:error, :invalid_or_unsupported_document}
  end

  defp validate_file_size(path) do
    case File.stat(path) do
      {:ok, %{size: size}} when size <= @max_file_size -> :ok
      {:ok, _stat} -> {:error, :file_too_large}
      {:error, _reason} -> {:error, :file_unreadable}
    end
  end

  defp validate_content(""), do: {:error, :no_extractable_text}
  defp validate_content(content) when byte_size(content) > @max_content_size,
    do: {:error, :extracted_text_too_large}

  defp validate_content(_content), do: :ok

  defp extract_content(path, extension) when extension in [".txt", ".md"] do
    File.read(path)
  end

  defp extract_content(path, ".pdf") do
    with {:ok, document} <- Pdf.Reader.open(path),
         {:ok, pages, _document} <- Pdf.Reader.read(document, shape: :text) do
      {:ok, Enum.join(pages, "\n\n")}
    else
      {:error, _reason} -> {:error, :pdf_could_not_be_read}
      _ -> {:error, :pdf_could_not_be_read}
    end
  end

  defp extract_content(path, ".docx") do
    with {:ok, binary} <- File.read(path),
         {:ok, files} <- :zip.unzip(binary, [:memory]),
         xml when is_binary(xml) <- find_document_xml(files),
         true <- byte_size(xml) <= @max_docx_xml_size,
         {document, _rest} <- :xmerl_scan.string(:binary.bin_to_list(xml), quiet: true) do
      paragraphs =
        document
        |> then(&:xmerl_xpath.string(String.to_charlist("//*[local-name()='p']"), &1))
        |> Enum.map(&paragraph_text/1)
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      {:ok, Enum.join(paragraphs, "\n\n")}
    else
      nil -> {:error, :invalid_docx}
      false -> {:error, :docx_content_too_large}
      {:error, _reason} -> {:error, :invalid_docx}
      _ -> {:error, :invalid_docx}
    end
  end

  defp extract_content(_path, _extension), do: {:error, :unsupported_file_type}

  defp find_document_xml(files) do
    Enum.find_value(files, fn {filename, contents} ->
      if List.to_string(filename) == "word/document.xml", do: contents
    end)
  end

  defp paragraph_text(paragraph) do
    paragraph
    |> then(&:xmerl_xpath.string(String.to_charlist(".//text()"), &1))
    |> Enum.map(fn text -> text |> elem(4) |> List.to_string() end)
    |> Enum.join()
  end
end
