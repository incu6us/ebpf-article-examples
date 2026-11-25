# 3. Find the slow query in Postgres

Article: "eBPF for developers: find the slow query in Postgres".

Postgres takes 180 ms of the request. Which query is it? The scripts get the text and the duration of every query from outside. The configuration of Postgres is not touched.

## Files

- `exec-simple-query.bt`: a uprobe on an internal function. It does not attach, because the packaged binary has no name for that function.
- `pg-parse-query.bt`: a uprobe on an exported function. It shows the query text once per connection.
- `query-start.bt`: the USDT probe `query__start`. It misses the queries of a normal driver.
- `slow-query.bt`: the script that works. Three USDT probes give text and duration.
- `check.sh`: runs all four against the lab.
- `cost.sh`: measures with pgbench what `slow-query.bt` costs.

## Run the check

```
./03-tracing-postgres/check.sh
```

## Run it by hand

The scripts name the binary as `/usr/lib/postgresql/18/bin/postgres`, the path on a normal server. In the lab the binary is inside the `db` container. Make a link with that path in the probe container first. Run this on your computer:

```
db=$(docker inspect -f '{{.State.Pid}}' ebpf-lab-db-1)
docker compose -f lab/compose.yaml exec probe ln -sfn /proc/$db/root/usr/lib/postgresql /usr/lib/postgresql
```

Then in the probe container:

```
bpftrace /series/03-tracing-postgres/slow-query.bt
```

Send a request from your computer:

```
curl localhost:18180/orders/42/summary
```

Output:

```
Attaching 6 probes...
180 ms  SELECT count(*), pg_sleep(0.18)::text FROM orders WHERE customer_id = $1
```

To see only queries of 100 ms or more:

```
bpftrace /series/03-tracing-postgres/slow-query.bt 100
```

## Good to know

- The query sleeps on purpose (`pg_sleep`), so the number is the same on every run.
- A probe on a binary fires in every process that runs the same file. Containers of the same image share that file. This is why the lab builds its own Postgres image with a private copy of the binary (`lab/db/Dockerfile`). Without it the script would also print the queries of every other `postgres:18` container on your machine.
- The script shows the full text of every query. Use it only where you are allowed to read them.
