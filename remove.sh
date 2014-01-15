#!/bin/sh
# uninstall a package: remove all the files, any empty directories left behind and the git repo.

usage() {
	echo
	echo "USAGE:"
	echo "   $0 <package>       remove a cloned package completely from the disk"
	echo "   $0 --list          list cloned packages"
	echo
	exit 1
}

package="$1"
[ "$package" ] || usage

[ -d "_git/$package/.git" ] || {
	echo
	echo "ERROR: unknown package $1"
	usage
}

files="$(GIT_DIR=_git/$package/.git git ls-files)"

# remove files
for file in $files; do
	rm $file
done

# remove empty directories
for file in $files; do
	echo "$(dirname "$file")"
done | uniq | while read dir; do
	[ "$dir" != "." ] && /bin/rmdir -p --ignore-fail-on-non-empty "$dir"
done

# remove the git dir
rm -rf _git/$package
