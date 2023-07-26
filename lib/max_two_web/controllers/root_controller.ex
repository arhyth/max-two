defmodule MaxTwoWeb.RootController do
  use MaxTwoWeb, :controller

  @timeout 1000

  @doc """
  Calls the user sidecar genserver to retrieve at most 2 users
  and the timestamp of the last query served.
  """
  def get(conn, _) do
    {users, ts} = GenServer.call(MaxTwo.Sidecar, :get, @timeout)
    users = Enum.map(users, fn u -> %{id: u.id, points: u.points} end)
    render(conn, :get, users: users, timestamp: ts)
  end
end
