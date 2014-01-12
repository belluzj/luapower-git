#!/bin/sh
printf "%-16s  %s\n" "$PROJECT" "$(git describe --tags --long --dirty --always)"
