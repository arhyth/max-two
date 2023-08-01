defmodule MaxTwoWeb.RootController do
  use MaxTwoWeb, :controller

  @doc """
  Calls the users sidecar
  """
  def get(conn, _) do
    {users, ts}  = users_sidecar().get_users()
    users = Enum.map(users, fn u -> %{id: u.id, points: u.points} end)
    render(conn, :get, users: users, timestamp: ts)
  end

  defp users_sidecar do
    Application.get_env(:max_two, :users_sidecar, MaxTwo.UsersSidecar)
  end
end
