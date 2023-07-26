defmodule MaxTwo.Repo.Migrations.AddUsersPointsIndex do
  use Ecto.Migration

  def up do
    create index("users", [:points])
  end

  def down do
    drop index("users", [:points])
  end
end
