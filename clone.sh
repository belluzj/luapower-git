#!/bin/sh
# clone a package (or all packages) from github, or list uncloned packages

usage() {
	[ "$@" ] && {
		echo
		echo "ERROR: $@"
	}
	echo
	echo "USAGE:"
	echo "   clone <package>        clone a package"
	echo "   clone --list           list uncloned packages"
	echo "   clone --all            clone all packages"
	echo
	exit 1
}

list_uncloned() {
	for f in _git/*.exclude; do
		f=${f#_git/}
		f=${f%.exclude}
		[ ! -d _git/$f/.git ] && echo $f
	done
}

clone_all() {
	for package in `list_uncloned`; do
		"$0" "$package"
	done
}

[ "$1" ] || usage
[ "$1" == "--all" ] && { clone_all; exit; }
[ "$1" == "--list" ] && { list_uncloned; exit; }

[ -f _git/$1.exclude ] || usage "unknown package $1"
[ ! -d _git/$1/.git ] || usage "$1 already cloned"

mkdir -p _git/$1
export GIT_DIR=_git/$1/.git

git init
git config --local core.worktree ../../..
git config --local core.excludesfile _git/$1.exclude
mkdir -p $GIT_DIR/hooks && \
	cp -f _git/pre-commit _git/post-commit $GIT_DIR/hooks/
git remote add origin "ssh://git@github.com/luapower/$1.git"
git fetch
git branch --track master origin/master
git checkout

