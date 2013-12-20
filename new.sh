# create a package template and initialize a git repo for it

set -e # break on first error

package="$1"; [ "$package" ] || { echo "usage: $0 <package>"; exit 1; }

[ -d "git-templates/$package" ] && {
	echo "error: package '$package' already exists. exiting."
	exit 1
}

mkdir -p git-templates/$package/info

echo "\
[core]
	worktree = ../../../../lua-files
" > git-templates/$package/config

echo "
*
!/$package*

!/bin/
!/bin/$package*

!/linux/
!/linux/bin/
!/linux/bin/lib$package*

!/csrc/
!/csrc/$package/
!/csrc/$package/**

" >> git-templates/$package/info/exclude

mkdir -p git-repos/$package

cd git-repos/$package

git init --template=../../git-templates/$package

echo "Now go tweak git-repos/$package/.git/info/exclude."
