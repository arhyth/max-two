defmodule MaxTwoWeb.RootControllerTest do
  use MaxTwoWeb.ConnCase, async: true

  alias MaxTwo.Users.User
  import Mox, only: [stub: 3]

  describe "get" do
    test "returns at most 2 users and a timestamp", %{conn: conn} do
      users = [
        %User{id: 99, points: 1},
        %User{id: 100, points: 2}
      ]
      ts = NaiveDateTime.utc_now()
      stub(MaxTwo.Users.SidecarMock, :get_users, fn -> {users, ts} end)

      conn = get(conn, "/")

      ts_str = Calendar.strftime(ts, "%c")
      users_key_str = [
        %{"id" => 99, "points" => 1},
        %{"id" => 100, "points" => 2},
      ]

      assert json_response(conn, 200) == %{"users" => users_key_str, "timestamp" => ts_str}
    end

    # This does not work, unfortunately, and so the timeout error scenario in
    # MaxTwoWeb.RootController.get -> MaxTwo.Users.GenSidecar.get_users -> GenServer.call(...)
    # cannot be tested to be handled properly.
    # In a genserver timeout, the caller exits which in the case of tests is ultimately the test process.
    # And as far as I know, there is no way to configure the Elixir test process to trap exits.
    #
    # setup :set_mox_global
    # test "returns 503 on timeout", %{conn: conn} do
    #   stub(MaxTwo.UsersServiceMock, :update_users_points, fn _trigger_interval, _page_limit -> :ok end)
    #   stub(MaxTwo.UsersServiceMock, :get_with_min_points, fn _n ->
    #     Process.sleep(5_100)
    #     [%User{id: 99, points: 1}, %User{id: 100, points: 2}]
    #   end)

    #   Application.put_env(:max_two, :users_sidecar, MaxTwo.Users.GenSidecar)
    #   opts = [
    #     users_service: MaxTwo.UsersServiceMock,
    #   ]
    #   GenServer.start_link(Sidecar, opts, name: Sidecar)
    #   on_exit(fn -> GenServer.stop(Sidecar) end)

    #   conn = get(conn, "/")
    #   assert json_response(conn, 503) == %{"error" => "try again later"}
    # end
  end
end
