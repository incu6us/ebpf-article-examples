#!/bin/sh
# Runs the scripts of this chapter against the lab and checks their output.
# SAVE=1 ./check.sh also keeps the raw output of every step in images/src/.
set -eu
. "$(dirname "$0")/../lab/lib.sh"
dir=/series/03-tracing-postgres
bin=/usr/lib/postgresql/18/bin/postgres

lab_up
# The scripts name the binary by the path it has on a normal server. In the lab the
# binary lives in the db container, so the probe container gets a link to it.
db=$(docker inspect -f '{{.State.Pid}}' "$(dc ps -q db)")
dc exec -T probe ln -sfn "/proc/$db/root/usr/lib/postgresql" /usr/lib/postgresql

# run_psql <command>: like run with two requests, plus one query typed into psql.
psql_query() {
	dc exec -T db psql -U postgres -d shop -Atc 'SELECT count(*) FROM orders WHERE customer_id = 7' > /dev/null
}
run_psql() {
	RUN_EXTRA=psql_query
	run "$1" 2
	RUN_EXTRA=
}

dc exec -T probe sh -c "bpftrace -l 'usdt:$bin:*' | wc -l" > "$OUT"
keep usdt-count
expect '^57$' "the binary has 57 USDT probes"

dc exec -T probe sh -c "bpftrace -l 'uprobe:$bin:*' | wc -l" > "$OUT"
keep uprobe-count
expect '^[0-9]{4,}$' "the binary still has thousands of exported functions"

dc exec -T probe sh -c "bpftrace $dir/exec-simple-query.bt 2>&1" > "$OUT" || true
keep exec-simple-query
expect '^No probes to attach$' "exec-simple-query.bt: the uprobe on a function that is not exported does not attach"

run_psql "bpftrace $dir/query-start.bt"
keep query-start
expect '^SELECT count\(\*\) FROM orders WHERE customer_id = 7$' "query-start.bt: sees the query typed into psql"
reject 'pg_sleep' "query-start.bt: does not see the prepared statement of the service"

run_psql "bpftrace $dir/slow-query.bt"
keep slow-query
expect '^1[7-9][0-9] ms  SELECT count\(\*\), pg_sleep\(0\.18\)::text FROM orders WHERE customer_id = \$1$' "slow-query.bt: names the query of the service with its duration"
expect '^0 ms  SELECT count\(\*\) FROM orders WHERE customer_id = 7$' "slow-query.bt: also sees the query typed into psql"

run_psql "bpftrace $dir/slow-query.bt 100"
keep slow-query-100
expect '^1[7-9][0-9] ms  SELECT count\(\*\), pg_sleep' "slow-query.bt 100: prints the slow query"
reject '^0 ms' "slow-query.bt 100: skips the fast one"

# A prepared statement is parsed once per connection, so start with new connections.
dc restart orders > /dev/null 2>&1
sleep 2
run_psql "bpftrace $dir/pg-parse-query.bt"
keep pg-parse-query
n=$(grep -c 'pg_sleep' "$OUT" || true)
if [ "$n" = 1 ]; then echo "ok    pg-parse-query.bt: two requests on a new connection, the query is parsed once"; else echo "FAIL  pg-parse-query.bt: expected the query once, got $n"; cat "$OUT"; fail=1; fi

rm -f "$OUT" "$RESP"
exit $fail
