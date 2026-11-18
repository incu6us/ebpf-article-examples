#!/bin/sh
# Runs the scripts of this chapter against the lab and checks their output.
set -eu
. "$(dirname "$0")/../lab/lib.sh"

lab_up

run "bpftrace /series/01-first-look/opens.bt"
expect '^orders +/var/log/orders/audit.log$' "opens.bt prints the open of the audit log among all others"

run "bpftrace /series/01-first-look/who-opens.bt" 2
expect '^orders \(pid [0-9]+\) opened /var/log/orders/audit.log$' "who-opens.bt names the process and its PID"

run "bpftrace /series/01-first-look/count.bt" 3
expect '^@opens\[orders\]: 3$' "count.bt counts three opens for three requests"

run "bpftrace /series/01-first-look/open-time.bt"
expect '^open for [0-9]+ us$' "open-time.bt measures how long the file stays open"

rm -f "$OUT" "$RESP"
exit $fail
