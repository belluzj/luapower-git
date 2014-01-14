#!/bin/sh
# clone a package from github

set -e # break on errors
die() { echo "$@" >&2; exit 1; }
package="$1"; [ "$package" ] || die "usage: $0 <package>"
[ -f "$package.exclude" ] || die "unknown package $package"
[ ! -d $package/.git ] || die "$package already cloned"

mkdir -p _git/$package
export GIT_DIR=_git/$package/.git

git init
git config --local core.worktree ../../..
git config --local core.excludesfile _git/$package.exclude
git remote add origin ssh://git@github.com/luapower/$package.git
git fetch
git branch --track master origin/master
git checkout
