# Shared by the check.sh of every chapter. Source it, do not run it.
LAB=$(cd "$(dirname "$0")/../lab" && pwd)
URL=localhost:${LAB_PORT:-18180}/orders/42/summary
OUT=$(mktemp)
RESP=$(mktemp)
fail=0

dc() { docker compose -f "$LAB/compose.yaml" "$@"; }

lab_up() {
	dc up -d --build --wait
	curl -sf -o /dev/null --retry 10 --retry-connrefused "$URL"
	# The CPU of the Docker VM: aarch64 or x86_64. Some checks depend on it.
	ARCH=$(dc exec -T probe uname -m)
}

# run <command> [requests]: starts a probe in the probe container, sends requests
# (default 1) while it is attached and keeps the output in $OUT. The answer of the
# last request (with the timings measured by the service itself) is in $RESP.
run() {
	: > "$OUT" # empty before the start, so the wait below never sees the last output
	dc exec -T probe sh -c "echo \$\$ > /tmp/run.pid; exec timeout -s INT 60 $1 2>&1" > "$OUT" &
	# A probe needs from one to several seconds to start, more on a cold machine.
	# Its first line ("Attaching 1 probe...") says that it is ready.
	i=0
	until [ -s "$OUT" ] || [ $i -ge 60 ]; do sleep 0.5; i=$((i + 1)); done
	ready=$(date +%s)
	sleep 1
	n=${2:-1}
	while [ "$n" -gt 0 ]; do curl -sf -o "$RESP" "$URL"; n=$((n - 1)); done
	# 12 s after it is ready the probe gets Ctrl-C and prints its maps. Only this
	# probe: the container sees every process of the host.
	left=$((ready + 12 - $(date +%s)))
	[ $left -gt 0 ] && sleep $left
	dc exec -T probe sh -c 'kill -INT $(cat /tmp/run.pid)' || true
	wait
}

expect() {
	if grep -Eq "$1" "$OUT"; then echo "ok    $2"; else echo "FAIL  $2"; cat "$OUT"; fail=1; fi
}

# keep <name>: with SAVE=1 the output of the last run is kept as
# images/src/<name>.txt in the chapter. If requests were sent since the last
# keep, the answer of the service follows.
keep() {
	if [ "${SAVE:-}" = 1 ]; then
		mkdir -p "$(dirname "$0")/images/src"
		cat "$OUT" > "$(dirname "$0")/images/src/$1.txt"
		[ -s "$RESP" ] && { echo "--- service answer"; cat "$RESP"; } >> "$(dirname "$0")/images/src/$1.txt"
	fi
	: > "$RESP"
}

# reject <pattern> <text>: the opposite of expect.
reject() {
	if grep -Eq "$1" "$OUT"; then echo "FAIL  $2"; cat "$OUT"; fail=1; else echo "ok    $2"; fi
}
