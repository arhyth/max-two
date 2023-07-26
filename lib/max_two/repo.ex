defmodule MaxTwo.Repo do
  use Ecto.Repo,
    otp_app: :max_two,
    adapter: Ecto.Adapters.Postgres

  use Paginator
end
