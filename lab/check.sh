#!/bin/sh
# Runs the check of every chapter of the series against the lab, in publish order.
# A chapter that is not in this copy of the repository is skipped.
# Usage: ./check.sh           all chapters
#        SAVE=1 ./check.sh    also keeps the raw output of every step in <chapter>/images/src/
#                             (chapters 2 to 6 and the Go chapter)
set -u
cd "$(dirname "$0")/.."
fail=0
out=$(mktemp)
for article in 01-first-look 02-where-the-time-goes 03-tracing-postgres go-developers 04-real-program 05-outgoing-calls 06-opentelemetry; do
	[ -d "$article" ] || continue
	echo "=== $article"
	if "./$article/check.sh" > "$out" 2>&1; then
		grep -E '^(ok|FAIL) ' "$out"
	else
		cat "$out" # the full output helps to see why a step failed
		fail=1
	fi
done
rm -f "$out"
exit $fail
