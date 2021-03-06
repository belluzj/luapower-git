#!/bin/sh
# set git wrapper to track a project, or list projects

# mingw doesn't set these
[ "$PS1" ] || export PS1="\\w \\$ "

[ "$1" ] || {
	cd _git && for f in *; do [ -d "$f/.git" ] && echo "$f"; done
	exit 0
}

export PROJECT="$1"
export GIT_DIR="_git/$1/.git"
echo "tracking $1"
git status -s
echo
PS1="[$1] \u@\h:\w\$ " bash -i
