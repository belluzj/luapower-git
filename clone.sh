#!/bin/sh
# clone a package (or all packages) from remote, or list uncloned packages

usage() {
	[ "$@" ] && {
		echo
		echo "ERROR: $@"
	}
	echo
	echo "USAGE:"
	echo "   $0 <package> [origin | url]    clone a package"
	echo "   $0 --list                      list uncloned packages"
	echo "   $0 --all                       clone all packages"
	echo
	exit 1
}

list_uncloned() {
	(cd _git
	for f in *.origin; do
		f=${f%.origin}
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

[ ! -d _git/$1/.git ] || usage "$1 already cloned"

if [ "$2" = "" ]; then
	[ -f "_git/$1.origin" ] || usage "unknown origin for $1"
	origin=$(cat _git/$1.origin)
	[ -f _git/$origin.baseurl ] || usage "missing origin url for origin $origin"
	baseurl=$(cat _git/$origin.baseurl)
	url=$baseurl$1
else
	if [ -f "_git/$2.baseurl" ]; then
		baseurl=$(cat _git/$2.baseurl)
		url=$baseurl$1
	else
		url="$2"
	fi
fi

mkdir -p _git/$1
export GIT_DIR=_git/$1/.git

git init
git config -f $GIT_DIR/config core.worktree ../../..
git config -f $GIT_DIR/config core.excludesfile _git/$1.exclude
git remote add origin $url
git fetch
git branch --track master origin/master
git checkout

