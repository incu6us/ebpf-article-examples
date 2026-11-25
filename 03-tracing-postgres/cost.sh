#!/bin/sh
# What does slow-query.bt cost? pgbench with one client and select only queries,
# 10 s each: without the probe, with the probe printing every query, with the probe
# printing only queries of 100 ms or more, without the probe again.
# The result goes to images/src/cost.txt. Not part of check.sh: the numbers move
# from run to run, so there is nothing stable to assert.
set -eu
. "$(dirname "$0")/../lab/lib.sh"

lab_up
db=$(docker inspect -f '{{.State.Pid}}' "$(dc ps -q db)")
dc exec -T probe ln -sfn "/proc/$db/root/usr/lib/postgresql" /usr/lib/postgresql

mkdir -p "$(dirname "$0")/images/src"
dc exec -T db sh -c 'psql -U postgres -qc "DROP DATABASE IF EXISTS bench" -c "CREATE DATABASE bench" && pgbench -U postgres -i -q bench' > /dev/null 2>&1

bench() { dc exec -T db pgbench -U postgres -S -M prepared -c 1 -T 10 bench 2>&1 | grep -E '^(latency average|tps)'; }

{
	echo "--- without the probe"
	bench
	for min in 0 100; do
		echo "--- with slow-query.bt $min attached"
		dc exec -T probe sh -c "timeout -s INT 18 bpftrace /series/03-tracing-postgres/slow-query.bt $min > /tmp/cost.out 2>&1" &
		sleep 6
		bench
		wait || true
		echo "lines printed by the probe: $(dc exec -T probe sh -c 'grep -c " ms  " /tmp/cost.out || true')"
	done
	echo "--- without the probe"
	bench
} | tee "$(dirname "$0")/images/src/cost.txt"

dc exec -T db psql -U postgres -qc "DROP DATABASE bench" > /dev/null
rm -f "$OUT" "$RESP"
