# clone (or just pull) a package from github with --git-dir=$package/.git and --worktree=..

package="$1"; [ "$package" ] || { echo "usage: $0 <package>" >&2; exit 1; }

url="ssh://git@github.com/luapower/$package.git"
# use this if you don't have a ssh key
# url="https://github.com/luapower/$package.git"

[ -d $package/.git ] || {
	mkdir -p $package
	cd $package
	git init
	git config core.worktree ../../..
	git config core.excludesfile _git/$package.exclude
	cd ../..
	git --git-dir=_git/$package/.git remote add origin "$url"
	git --git-dir=_git/$package/.git fetch --all
	git --git-dir=_git/$package/.git branch -u origin/master
	cd _git
}

cd .. && git --git-dir=_git/$package/.git pull origin master
