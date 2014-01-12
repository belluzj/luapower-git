#!/bin/sh
# check what packages need pushing

for package in `./proj.sh`; do
	[ "$(git --git-dir=_git/$package/.git rev-list HEAD...origin/master --count)" != "0" ] && echo "$package"
done
