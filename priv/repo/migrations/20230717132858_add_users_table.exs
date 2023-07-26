defmodule MaxTwo.Repo.Migrations.AddUsersTable do
  use Ecto.Migration

  def up do
    create table("users") do
      add :points, :integer

      timestamps()
    end
  end

  def down do
    drop table("users")
  end
end
