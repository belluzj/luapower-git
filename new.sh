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
!/bin/
!/csrc/
!/bin/mingw32/
!/bin/linux32/
!/media/

!/$package*
!/bin/mingw32/$package*
!/bin/linux32/lib$package*
!/csrc/$package/
!/csrc/$package/**

" >> git-templates/$package/info/exclude

mkdir -p git-repos/$package

cd git-repos/$package

git init --template=../../git-templates/$package

echo "Package created with files from ../lua-files/$package."
echo "Now go tweak git-repos/$package/.git/info/exclude."
