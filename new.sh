# create a package template and initialize a git repo for it

set -e # break on first error

package="$1"; [ "$package" ] || { echo "usage: $0 <package>" >&2; exit 1; }
[ -f "$package.exclude" ] && { echo "error: package already exists." >&2; exit 1; }

echo "\
*
!/bin/
!/csrc/
!/bin/mingw32/
!/bin/linux32/
!/media/

!/$package*
!/$package/
!/$package/**
!/bin/mingw32/$package*
!/bin/linux32/lib$package*
!/csrc/$package/
!/csrc/$package/**

" > $package.exclude

./clone.sh $package
