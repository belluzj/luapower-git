#!/bin/sh
# push tags to remote

# mingw doesn't set these
[ "$HOME"] || export HOME="$USERPROFILE"

for package in `./proj.sh`; do
	echo " ~~~ $package ~~~ "
	git --git-dir=_git/$package/.git push --tags
done
