#!/bin/sh
# list the most recent git tag on current branch for each package

show_version() {
	tag="$(git --git-dir=_git/$1/.git describe --tags --long --dirty --always)"
	printf "%-16s  %s\n" "$1" "$tag"
}

[ "$1" ] && { show_version $1; exit; }

for package in `./proj.sh`; do
	show_version $package
done
