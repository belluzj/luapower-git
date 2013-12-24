# clone a package from github

package="$1"; [ "$package" ] || { echo "usage: $0 <package>"; exit 1; }

[ -d git-repos/$package/.git ] && exit 1

url=ssh://git@github.com/capr/$package.git
#url=https://capr@github.com/capr/$package.git  # use this if you don't have a ssh key

mkdir -p ../lua-files

git clone $url --template=git-templates/$package --no-checkout git-repos/$package

git --git-dir=git-repos/$package/.git checkout
