Max Two
===

A service that returns at most 2 users based on a random minimum number you cannot see :ghost:.

### Original requirements
1. seed 1M users with field `points: 0` into the repository
2. service should update 1M users, each with a random `points` value, every 1 minute
3. service should expose an endpoint that returns at most 2 users based on another random minimum number that is also updated every 1 minute

## Development

### Dependencies
You may or may not use [asdf](https://asdf-vm.com/), docker, etc. Up to you.
- erlang (ver 26.0.2 via asdf)
- elixir (ver 1.15.3 via asdf)
- phoenix (ver 1.7.7)
- postgres (ver 15 via docker)
- [paginator](https://github.com/duffelhq/paginator) (ver 1.2.0)

Fetch dependencies
```
mix deps.get
```
Optional: Pull up docker image for postgres for local use and testing.
<br>:warning: This is an ephemeral repository. No data or schema changes will survive container removal.
```
docker pull postgres:15
docker run -d --name max_two_db -p 5432:5432 -e POSTGRES_USER=maxtwo -e POSTGRES_PASSWORD=passwswsw postgres:15
```
Optional: change the `POSTGRES_USER`, `POSTGRES_PASSWORD` with your credentials and configure corresponding fields in  `dev.exs` and/or `test.exs` accordingly.

To play around the application or do some manual testing...
```
MIX_ENV=dev mix ecto.drop
MIX_ENV=dev mix ecto.setup
```
Run the server
```
mix phx.server
```

## Testing
To run unit / DB integration tests...
```
MIX_ENV=test mix ecto.drop
mix test
```

## Usage
### Server configuration
In `config.exs` ...
```
config :max_two, MaxTwo,
    # interval between update starts, in milliseconds
    update_interval_ms: 60_000,

    # number of rows fetched from DB on each query
    # Setting a lower figure (eg. 10_000) significantly impacts the latency of the operation
    page_limit: 20_000,

    # count of users streamed to Flow stage/partitions
    # to trigger actual repo update
    trigger_interval: 4_000,

    # minimum cooldown between updates, in milliseconds
    # so the DB does not get strangled by overlapping (it's possible) update rounds
    min_cooldown_ms: 10_000


config :max_two, MaxTwo.Repo,
  # Depending on the DB instance, fiddling with this may or may not be necessary.
  # If it's too low, we get `DBConnection.ConnectionError` due to queries
  # (from users points update task) timing out in the DB queue.
  pool_size: 20
```

### Request
```
curl localhost:4000/
```

### Response
```json
{
  "users": [{"id": 1, "points": 30}, {"id": 72, "points": 30}],
  "timestamp": "2020-07-30 17:09:33"
}
```

### Notes / FAQ

:pen: This repo / coding exercise was part of the application process to one of a few well-known "Elixir shop" companies in the world. The following points are notes I made as I was implementing the excercise. I'm putting this out into the public only to demonstrate my Elixir coding skills. Any style or structure apparent here is only to fulfill the absolute necessity. The only coding style I personally adhere to is "as minimal structure and/or abstraction as necessary", everything else is fluid.

1. ~~Why are there no tests?~~ There are unit tests but none that covers the system as a whole because nondeterministic behavior and genservers. That is, nondeterminism not only due to the random numbers requirement but also due to the timing of effects (updates happening piecemeal over time rather than in one transactional go) as an effect of the scale (eg. 1m rows in <1min) requirement. ~~I thought about parameterizing the "update function" that's passed to the spawn process, to be able to write some tests. But it seems superficial, and at that point you ask yourself as I did,~~ is the thing I'm testing still the same thing I'm running? I ended up testing pieces of the logic in isolation. So, still not the same thing but close enough, I guess.

2. Why do updates not run exactly every minute? *It actually does, most of the time.* In a more realistic production app/service when your resources are at their limit, you want to let them breathe a bit. Otherwise, you run the risk of spiralling down to catastrophic failure. But since this is also an imaginary app/service, I could just assume that the update interval of 1min is a technical requirement and can be relaxed rather than a business critical requirement. Hence, I added a cooldown logic in case the update task exceeds the 1min interval.

3. Why not persist the last query timestamp to the DB so that it survives server restart? I could but it's not a specified behavior. Also, it's a "commutative" change (eg. I can add it now and send my solution a bit later or I can add it "later" and send my solution a little earlier. Any way works. The choice would not impact the design of the service except that I'm optimizing for delivery time and so, no persistence.)

4. Why use an unlinked process for the update task? Linking does not provide any benefit here because the task is going to be restarted anyway without supervision tree goodies. Also, even if it was a one-off task that should only be restarted on failure, some sophisticated (complicated?) logic for "checking in/out" intermediate state and progress would have to be added to be able to restart/respawn at failure point. 