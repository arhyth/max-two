defmodule MaxTwo.Users.User do
  @moduledoc """
  Schema for data in users repository
  """

  use Ecto.Schema

  schema "users" do
    field :points, :integer, default: 0

    timestamps()
  end
end
