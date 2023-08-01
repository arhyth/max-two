defmodule MaxTwo.UsersTest do
  use MaxTwo.DataCase

  import Ecto.Query

  describe "get_with_min_points/1" do
    test "returns at most 2 users with points greater than specified minimum" do
      users =
        Enum.map(2..4, fn p ->
          MaxTwo.Repo.insert!(%MaxTwo.Users.User{points: p})
        end)
      min = 3
      returned = MaxTwo.Users.get_with_min_points(min)
      refute length(users) == length(returned)
      assert Enum.all?(returned, fn u -> u.points > min end)
    end
  end

  describe "cursor_paginate/3" do
    test "returns at most `page size` amount of users ordered by specified keys" do
      Enum.each(1..5, fn p ->
        MaxTwo.Repo.insert!(%MaxTwo.Users.User{points: p})
      end)

      page_size = 3
      {users, _} = MaxTwo.Users.cursor_paginate([points: :desc], page_size, [fields: [:id, :points]])
      assert length(users) == page_size
      # assert correct order by accumulating count while order is correct
      {_last_points_val, count} =
        Enum.reduce_while(users, {999, 0}, fn u, {last_points_val, count} ->
          if last_points_val >= u.points do
            {:cont, {u.points, count + 1}}
          else
            {:halt, {last_points_val, count}}
          end
        end)
      assert count == page_size

      page_size = 5
      {users, _} = MaxTwo.Users.cursor_paginate([id: :asc], page_size)
      assert length(users) == page_size
      # same as above but different criteria (eg. id)
      {_last_id_val, count} =
        Enum.reduce_while(users, {-1, 0}, fn u, {last_id_val, count} ->
          if last_id_val <= u.id do
            {:cont, {u.id, count + 1}}
          else
            {:halt, {last_id_val, count}}
          end
        end)
      assert count == page_size
    end
  end

  describe "set_points/1" do
    setup do
      pts = 99
      user_ids =
        1..5
        |> Enum.map(fn _ ->
          MaxTwo.Repo.insert!(%MaxTwo.Users.User{points: pts})
        end)
        |> Enum.map(&(&1.id))

      %{user_ids: user_ids, points: pts}
    end

    test "sets points of users having ids in specified list to specified int",
        %{user_ids: uids, points: pts} do
      MaxTwo.Users.set_points(uids, pts + 1)
      users =
        MaxTwo.Users.User
        |> where([u], u.id in fragment("(?)", ^uids))
        |> MaxTwo.Repo.all()

      assert Enum.all?(users, fn u -> u.points == pts + 1 end)
    end

    test "sets points of user with specified id to specified int",
        %{user_ids: [uid | _], points: pts} do
      MaxTwo.Users.set_points(uid, pts + 1)
      user = MaxTwo.Repo.get(MaxTwo.Users.User, uid)
      assert user.points == pts + 1
    end
  end
end
