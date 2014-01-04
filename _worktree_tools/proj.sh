#!/bin/sh
# set git wrapper to track a project, or list projects

# mingw doesn't set these
[ "$HOME" ] || export HOME="$USERPROFILE"
[ "$PS1" ] || export PS1="\\w \\$ "

[ "$1" ] || {
	cd _git && for f in *; do [ -d "$f/.git" ] && echo "$f"; done
	exit
}

export GIT_DIR="_git/$1/.git"
echo "tracking $1"
echo "------------------"
git ls-files
echo
PS1="[$1] $PS1" bash -i
