Max Two
===

A service that returns at most 2 users based on a random minimum number you cannot see :ghost:.

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

1. Great stuff! This was a deceptively difficult task. At first, I thought to myself this should be easy, just front a genserver to a repo. But updating 1M rows in <60s that really took the difficulty level up some notches. I also forgot a lot of OTP things as I haven't written Elixir code for more than a year now. It's quite a challenging refresher. I really enjoyed it.

2. Why are there no tests? Because nondeterministic behavior and genservers; that is, nondeterminism not only due to the random numbers requirement but also due to the timing of effects (updates happening piecemeal over time rather than in one transactional go) as an effect of the scale (eg. 1m rows in <1min) requirement. I thought about parameterizing the "update function" that's passed to the spawn process, to be able to write some tests. But it seems superficial, and at that point you ask yourself as I did, is the thing I'm testing still the same thing I'm running?

3. The repo could not be cloned to test if the environment setup was actually reproducible (without Docker which I personally don't use locally aside from running the dev DB). When I tried to clone it, I only got the README.

5. Why do updates not run exactly every minute? Because in a more realistic production app/service, you want your resources to be able to breathe when they're at their limit. Otherwise you run the risk of spiralling down to catastrophic failure. But since this is also an imaginary app/service, I could just assume that the update interval of 1min is a technical requirement and can be relaxed rather than a business critical requirement.

6. Why not persist the last query timestamp to the DB so that it survives server restart? I could but it's not a specified behavior. Also, it's a "commutative" change (eg. I can add it now and send my solution a bit later or I can add it "later" and send my solution a little earlier. Any way works. The choice would not impact the design of the service except that I'm optimizing for delivery time and so, no persistence.)

7. Why use an unlinked process for the update task? Linking does not provide any benefit here because the task is going to be restarted anyway without supervision tree goodies. Also, even if it was a one-off task that should only be restarted on failure, some sophisticated (complicated?) logic for "checking out" intermediate state and progress would have to be added to be able to restart/respawn at failure point. 