#!/bin/sh
# Runs the scripts of this chapter against the lab and checks their output.
# SAVE=1 ./check.sh also keeps the raw output of every step in images/src/.
# Syscall numbers depend on the CPU. arm64: 22 epoll_pwait, 63 read, 64 write.
# x86-64: 281, 0 and 1 by the syscall table. Only the arm64 numbers were run here.
set -eu
. "$(dirname "$0")/../lab/lib.sh"

lab_up
orders=$(dc exec -T probe pgrep -xn orders)
case $ARCH in
	x86_64) wait_nr=281 read_nr=0 write_nr=1 ;;
	*) wait_nr=22 read_nr=63 write_nr=64 ;;
esac

run "bpftrace /series/02-where-the-time-goes/on-cpu.bt $orders"
keep on-cpu
expect '^@cpu_ns: [0-9]{6,7}$' "on-cpu.bt: the process is on a CPU for less than 10 ms"

run "bpftrace /series/02-where-the-time-goes/syscall-time.bt $orders"
keep syscall-time
# The total grows with the time the probe runs, so only the lower end is checked.
expect "^@us\\[$wait_nr\\]: [1-9][0-9]{6}\$" "syscall-time.bt: more than a second inside epoll_pwait"
expect "^@us\\[$read_nr\\]: [0-9]{1,3}\$" "syscall-time.bt: all reads together take under 1 ms"
expect "^@us\\[$write_nr\\]: [0-9]{1,3}\$" "syscall-time.bt: all writes together take under 1 ms"

run "bpftrace /series/02-where-the-time-goes/tcp-wait.bt $orders"
keep tcp-wait
expect '^remote port 5432: waited 1[7-9][0-9] ms$' "tcp-wait.bt: about 180 ms on the Postgres connection"
expect '^remote port 8443: waited 12[0-3][0-9] ms$' "tcp-wait.bt: about 1,200 ms on the LLM connection"

# A flaw that is kept on purpose, see README. A closed socket leaves its send time
# in the map and a later socket can get the same address. With several requests
# that gives lines with the port of an incoming connection. No assert: it depends
# on the memory allocator of the kernel. Chapter 4 starts from this output.
run "bpftrace /series/02-where-the-time-goes/tcp-wait.bt $orders" 3
keep tcp-wait-3-requests
echo "ok    tcp-wait.bt with three requests: $(grep -Ec '^remote port [0-9]{5}:' "$OUT" || true) extra lines from reused socket addresses (known flaw)"

rm -f "$OUT" "$RESP"
exit $fail
