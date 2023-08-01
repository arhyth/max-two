defmodule MaxTwo.SidecarTest do
  use ExUnit.Case, async: false

  import Mox

  alias MaxTwo.Users.GenSidecar, as: Sidecar

  describe "get_users/0" do
    # this and `async: false` are required for the genserver process
    # to be able to call mock/stubs setup by the test process
    setup :set_mox_global

    test "returns a tuple having a list and a timestamp that defaults to null on start" do
      stub_with(MaxTwo.UsersServiceMock, MaxTwo.UsersServiceStub)
      sidecar_spec = %{
        id: Sidecar,
        start: {Sidecar, :start_link, [[users_service: MaxTwo.UsersServiceMock]]}
      }
      start_supervised(sidecar_spec)
      {users, ts} = Sidecar.get_users()
      assert is_nil(ts)
      refute Enum.empty?(users)
      {_, ts} = Sidecar.get_users()
      refute is_nil(ts)
    end
  end
end
