defmodule MaxTwo.Users.SidecarStub do
  @behaviour MaxTwo.Users.Sidecar

  alias MaxTwo.Users.User

  @impl MaxTwo.Users.Sidecar
  def get_users() do
    {
      MaxTwo.UsersServiceStub.get_with_min_points(nil),
      NaiveDateTime.utc_now()
    }
  end
end

defmodule MaxTwo.UsersServiceStub do
  @behaviour MaxTwo.UsersService

  alias MaxTwo.Users.User

  @impl MaxTwo.UsersService
  def update_users_points(_trigger_interval, _page_limit), do: :ok

  @impl MaxTwo.UsersService
  def get_with_min_points(_min) do
    [%User{id: 99, points: 1}, %User{id: 100, points: 2}]
  end

  @impl MaxTwo.UsersService
  def cursor_paginate(_order_by, _page_size, _opts) do
    {
      [%User{id: 99, points: 1}, %User{id: 100, points: 2}],
      %{after: nil}
    }
  end
end
