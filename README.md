# eBPF for developers

The code for the article series "eBPF for developers". The series is for people who write services and have never touched the Linux kernel. Every chapter asks one question about a running service and answers it from outside, with no change to the code of the service.

Everything runs in Docker. You need no Linux machine, no Go and no C compiler on your computer.

## Chapters

| Directory | Question | Tool |
|---|---|---|
| `01-first-look` | Which process writes this file? | bpftrace, a tracepoint |
| `02-where-the-time-goes` | Where does a slow request wait? | bpftrace, kprobes |

Each directory has its own README with the commands and the output to expect. The next chapters come here when their articles are out.

## What you need

- Docker with Docker Compose. Docker Desktop on a Mac or on Windows is enough, because its virtual machine runs a Linux kernel.
- `curl` and a POSIX shell for the check scripts.

## Warning

The lab starts one container that is privileged and sees every process of the machine (on Docker Desktop: of its virtual machine). That is what eBPF needs. Run it on your own computer. Do not run it on a server that you share with other people.

## Quick start

```
git clone https://github.com/incu6us/ebpf-article-examples
cd ebpf-article-examples
```

Run the check of one chapter. It builds the lab, starts it, runs every script of the chapter and compares the output:

```
./02-where-the-time-goes/check.sh
```

The first run takes a few minutes, because Docker builds the images. Run everything:

```
./lab/check.sh
```

Stop the lab:

```
docker compose -f lab/compose.yaml down
```

## Work by hand

Start the lab and open a shell in the probe container:

```
docker compose -f lab/compose.yaml up -d --build --wait
docker compose -f lab/compose.yaml exec probe bash
```

Inside that shell the chapters are at `/series`. Start a script there:

```
bpftrace /series/02-where-the-time-goes/tcp-wait.bt $(pgrep -xn orders)
```

Then send a request from a second terminal on your computer:

```
curl localhost:18180/orders/42/summary
```

## The lab

One small service with two things behind it. All numbers are staged, so every run gives the same picture.

| Container | What it is |
|---|---|
| `orders` | The service, written in Go. `GET /orders/42/summary` takes about 1.4 s. |
| `db` | Postgres 18. The query of the service takes 180 ms. |
| `llm` | A fake LLM API with HTTPS under the name `api.llm.test`. Every call takes 1,200 ms. |
| `probe` | Ubuntu 24.04 with bpftrace, clang, bpftool and Go. All probes start here. |

The service also appends one line to `/var/log/orders/audit.log` for every request. That is the file of chapter 1.

One request is special. For `GET /orders/7/summary` the first LLM call gets no answer in time. The service gives up after 2 s and sends the call again, the way the SDKs of the LLM providers do. Later chapters look for that hidden call.

If port 18180 is taken on your computer, set `LAB_PORT`:

```
LAB_PORT=18181 ./02-where-the-time-goes/check.sh
```

## Tested on

Docker Desktop on a Mac with Apple Silicon: kernel 6.12, arm64. Every check passes there.

I have not run the lab on an x86-64 machine yet. One thing is known to differ there: the syscall numbers. The check of chapter 2 has the x86-64 numbers from the syscall table, but they were never run.

## Versions

The images are pinned, so the output stays the same: Ubuntu 24.04 with bpftrace 0.20.2 and clang 18, Postgres 18, Go 1.27.
