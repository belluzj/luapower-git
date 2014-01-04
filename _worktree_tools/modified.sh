#!/bin/sh
# show the status of all cloned packages

for package in `./proj.sh`; do
	git --git-dir=_git/$package/.git status -s
done
