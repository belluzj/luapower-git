# clone a package from github

package="$1"; [ "$package" ] || { echo "usage: $0 <package>"; exit 1; }

[ -d git-templates/$package ] || {
	echo "error: missing template for '$package'"
	exit 1
}

[ -d git-repos/$package ] && {
	echo "error: repo dir already exists for '$package'"
	exit 1
}

git clone ssh://git@github.com/capr/$package \
	--template=git-templates/$package --no-checkout git-repos/$package

git --git-dir=git-repos/$package/.git checkout
