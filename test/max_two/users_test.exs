defmodule MaxTwo.UsersTest do
  use MaxTwo.DataCase

  describe "get_users/2" do
    test "returns at most 2 users with points greater than specified minimum" do
      users =
        Enum.map(2..4, fn p ->
          MaxTwo.Repo.insert!(%MaxTwo.Users.User{points: p})
        end)
      min = 3
      returned = MaxTwo.Users.get_users(min)
      refute length(users) == length(returned)
      assert Enum.all?(returned, fn u -> u.points > min end)
    end
  end
end
