# 1. Find who opens a file

Article: "eBPF for developers: find who opens a file".

A file grows and nobody knows which process writes it. `lsof` does not help, because the file is open for a tenth of a millisecond. One tracepoint on the syscall `openat` names the writer.

## Files

- `opens.bt`: prints every open on the machine.
- `who-opens.bt`: prints only the opens of `/var/log/orders/audit.log`, with the process and its PID.
- `count.bt`: counts opens per process inside the kernel.
- `open-time.bt`: measures how long the audit log stays open.
- `check.sh`: runs all four against the lab.

## Run the check

```
./01-first-look/check.sh
```

## Run it by hand

In the probe container (see the README at the top for how to get a shell):

```
bpftrace /series/01-first-look/who-opens.bt
```

Send two requests from your computer:

```
curl localhost:18180/orders/42/summary
curl localhost:18180/orders/42/summary
```

Output:

```
Attaching 1 probe...
orders (pid 17863) opened /var/log/orders/audit.log
orders (pid 17863) opened /var/log/orders/audit.log
```

Your PID is different.

## The small lab from the article

The article ends with a lab that needs nothing from this repository, only Docker:

```
docker run --rm -it --privileged --pid=host ubuntu:24.04 bash
apt update && apt install -y bpftrace lsof
mount -t tracefs none /sys/kernel/tracing
mount -t debugfs none /sys/kernel/debug
cp /bin/bash /usr/local/bin/mystery
mystery -c 'while true; do echo "$(date +%T) tick" >> /tmp/audit.log; sleep 1; done' &
```

Then ask the kernel who writes `/tmp/audit.log`:

```
bpftrace -e '
tracepoint:syscalls:sys_enter_openat
/str(args.filename) == "/tmp/audit.log"/
{
  printf("%s (pid %d) opened %s\n", comm, pid, str(args.filename));
}'
```
