# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     MaxTwo.Repo.insert!(%MaxTwo.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
1..1_000_000
|> Stream.map(fn _ ->
  %{points: 0, inserted_at: now, updated_at: now}
end)
|> Stream.chunk_every(10_000)
|> Stream.each(fn batch ->
  MaxTwo.Repo.insert_all(MaxTwo.Users.User, batch, log: false)
end)
|> Stream.run()

# or use this if you want it a little bit faster (~4s vs ~10s)
#
# insert = "INSERT INTO public.users (id, points, inserted_at, updated_at)
# SELECT n, 0, now(), now()
# FROM generate_series(1, 1000000) as n"
