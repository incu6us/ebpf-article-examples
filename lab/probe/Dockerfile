# Probe box: runs privileged with the host PID namespace and holds the eBPF tools.
# bpftrace for articles 1 to 3. clang, libbpf, bpftool and Go for the C programs
# of the later articles.
FROM ubuntu:24.04
RUN apt-get update -qq \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
      bpftrace binutils procps curl ca-certificates \
      clang llvm libbpf-dev linux-tools-generic \
 && rm -rf /var/lib/apt/lists/* \
 # Ubuntu only ships bpftool next to a kernel version. Any version can dump BTF.
 && ln -s "$(find /usr/lib -name bpftool -type f | head -1)" /usr/local/bin/bpftool
# Go 1.27.4 is the version that made the output shown in the articles.
COPY --from=golang:1.27.4 /usr/local/go /usr/local/go
ENV PATH=/usr/local/go/bin:$PATH
WORKDIR /series
CMD ["sleep", "infinity"]
