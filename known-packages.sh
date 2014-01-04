#!/bin/sh
# list all known packages (cloned or uncloned)
cd "$(dirname "$0")"
for f in *.exclude; do echo "${f%.exclude}"; done
