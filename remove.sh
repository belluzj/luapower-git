#!/bin/sh
# uninstall a package: remove all the files, any empty directories left behind and the git repo.

package="$1"; [ "$package" ] || { echo "usage: $0 <package>" >&2; exit 1; }

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
