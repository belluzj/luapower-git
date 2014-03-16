#!/bin/sh
# uninstall a package: remove all the files, any empty directories left behind and the git repo.

usage() {
	[ "$@" ] && {
		echo
		echo "ERROR: $@"
	}
	echo
	echo "USAGE:"
	echo "   $0 <package>    remove a cloned package completely from the disk"
	echo "   $0 --list       list cloned packages"
	echo
	exit 1
}

list_cloned() {
	(cd _git
	for f in *; do
		[ -d "$f/.git" ] && echo "$f"
	done)
}

[ "$1" ] || usage
[ "$1" = "--list" ] && { list_cloned; exit; }
[ -d "_git/$1/.git" ] || usage "unknown package $1"

files="$(GIT_DIR=_git/$1/.git git ls-files)"

# remove files
for file in $files; do
	rm $file
done

# remove empty directories
for file in $files; do
	echo "$(dirname "$file")"
done | uniq | while read dir; do
	[ "$dir" != "." ] && /bin/rmdir -p "$dir" 2>/dev/null
done

# remove the git dir
rm -rf _git/$1/.git
rmdir _git/$1
