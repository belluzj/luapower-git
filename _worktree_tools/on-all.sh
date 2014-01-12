#!/bin/sh
# perform a command for each project in the context of PROJECT and GIT_DIR variables

for package in `./proj.sh`; do
	export PROJECT="$package"
	export GIT_DIR=_git/$package/.git
	"$@"
done
