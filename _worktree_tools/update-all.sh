#!/bin/sh
#git add, commit and push all repos with a commit message (good for bulk updates to documentation)

[ "$1" ] || { echo "usage: $0 <commit-message>"; exit 1; }

# mingw doesn't set these
[ "$HOME" ] || export HOME="$USERPROFILE"

for package in `./proj.sh`; do
	echo " ~~~ $package ~~~ "
	export GIT_DIR=_git/$package/.git
	git add -A
	git commit -m "$1"
	[ "$(git rev-list HEAD...origin/master --count)" != "0" ] && git push
done
