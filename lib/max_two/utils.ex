defmodule MaxTwo.Utils do
  @moduledoc """
  Utility functions
  """

  @doc """
  Returns a random number between 0 and n-1
  """
  def rand_less_one(n \\ 101), do: :rand.uniform(n) - 1
end
