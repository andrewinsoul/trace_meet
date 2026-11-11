defmodule TraceMeet.Accounts.Password do
  @iterations 600_000
  @key_length 32
  @dummy_salt "trace-meet-invalid-user-salt"

  def hash(password) when is_binary(password) do
    salt = :crypto.strong_rand_bytes(16)
    digest = derive(password, salt, @iterations)

    Enum.join(
      [
        "",
        "pbkdf2-sha256",
        Integer.to_string(@iterations),
        Base.url_encode64(salt, padding: false),
        Base.url_encode64(digest, padding: false)
      ],
      "$"
    )
  end

  def verify(password, encoded)
      when is_binary(password) and byte_size(password) <= 128 and is_binary(encoded) do
    case String.split(encoded, "$") do
      ["", "pbkdf2-sha256", iterations, salt, expected] ->
        with {iterations, ""} <- Integer.parse(iterations),
             {:ok, salt} <- Base.url_decode64(salt, padding: false),
             {:ok, expected} <- Base.url_decode64(expected, padding: false),
             true <- iterations >= 100_000 and iterations <= 2_000_000 do
          if byte_size(expected) == @key_length do
            actual = derive(password, salt, iterations)
            Plug.Crypto.secure_compare(actual, expected)
          else
            false
          end
        else
          _ -> false
        end

      _ ->
        false
    end
  end

  def verify(_, _), do: false

  def dummy_verify(password) when is_binary(password) do
    password = binary_part(password, 0, min(byte_size(password), 128))

    derive(password, @dummy_salt, @iterations)
    |> then(fn _ -> false end)
  end

  def dummy_verify(_), do: dummy_verify("")

  defp derive(password, salt, iterations) do
    :crypto.pbkdf2_hmac(:sha256, password, salt, iterations, @key_length)
  end
end
