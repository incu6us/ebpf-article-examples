# Postgres with its own copy of the server binary.
# A probe on a binary file fires in every process that runs this file. Containers
# of the same image share the file, so without the copy the probes of article 3
# would also print the queries of every other postgres:18 container on the machine.
FROM postgres:18
RUN cp -p /usr/lib/postgresql/18/bin/postgres /tmp/postgres \
 && mv /tmp/postgres /usr/lib/postgresql/18/bin/postgres
