# 2. Find where a slow request waits

Article: "eBPF for developers: find where a slow request waits".

`GET /orders/42/summary` takes 1.4 s and the CPU is idle. Three scripts ask the kernel where the time goes.

## Files

- `on-cpu.bt`: how long is the process on a CPU?
- `syscall-time.bt`: in which syscalls does it spend its time?
- `tcp-wait.bt`: on which TCP connection does it wait and for how long?
- `syscall-names.bt`: like `syscall-time.bt` with names in place of numbers. It needs 611 probes and about 20 s to attach, so the article does not use it.
- `check.sh`: runs the first three against the lab.

## Run the check

```
./02-where-the-time-goes/check.sh
```

## Run it by hand

In the probe container:

```
bpftrace /series/02-where-the-time-goes/tcp-wait.bt $(pgrep -xn orders)
```

Send one request from your computer:

```
curl localhost:18180/orders/42/summary
```

Output:

```
Attaching 4 probes...
remote port 5432: waited 0 ms
remote port 5432: waited 186 ms
remote port 8443: waited 1203 ms
```

Port 5432 is Postgres and port 8443 is the LLM API. The line with 0 ms is the health check of the database driver.

The other two scripts take the PID in the same way. Stop them with Ctrl-C to see the result.

## Good to know

- `syscall-time.bt` prints syscall numbers. They depend on the CPU. On arm64: 22 is epoll_pwait, 98 is futex, 63 is read, 64 is write.
- `tcp-wait.bt` is good for one request. With several requests it can print lines with a port that is no server, like `remote port 41448: waited 13 ms`. The kernel gives the memory address of a closed connection to a later one. The script keeps its data by that address. Chapter 4 fixes this.
