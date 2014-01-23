#!/bin/sh
# clone a package (or all packages) from remote, or list uncloned packages

usage() {
	[ "$@" ] && {
		echo
		echo "ERROR: $@"
	}
	echo
	echo "USAGE:"
	echo "   $0 <package> [remote | url]    clone a package"
	echo "   $0 --list                      list uncloned packages"
	echo "   $0 --all                       clone all packages"
	echo
	exit 1
}

list_uncloned() {
	(cd _git
	for f in *.exclude; do
		f=${f%.exclude}
		[ ! -d $f/.git ] && echo $f
	done)
}

clone_all() {
	for package in `list_uncloned`; do
		"$0" "$package"
	done
}

[ "$1" ] || usage
[ "$1" = "--all" ] && { clone_all; exit; }
[ "$1" = "--list" ] && { list_uncloned; exit; }
[ "$2" ] && remote="$2" || remote=default
[ -f _git/$remote.remote ] && url=$(cat _git/$remote.remote)/$1 || url=$remote

[ -f _git/$1.exclude ] || usage "unknown package $1"
[ ! -d _git/$1/.git ] || usage "$1 already cloned"

mkdir -p _git/$1
export GIT_DIR=_git/$1/.git

git init
git config -f $GIT_DIR/config core.worktree ../../..
git config -f $GIT_DIR/config core.excludesfile _git/$1.exclude
git remote add origin $url
git fetch
git branch --track master origin/master
git checkout

