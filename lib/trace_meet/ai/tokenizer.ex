defmodule TraceMeet.AI.Tokenizer do
  @moduledoc """
  Model-independent transcript token counting backed by Tiktokenex.
  """

  @encoding :o200k_base

  def initialize do
    Tiktokenex.Ranks.warmup()
  end

  def count(text) when is_binary(text) do
    Tiktokenex.count(text, @encoding)
  end
end
