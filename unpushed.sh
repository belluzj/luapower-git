# check what packages need pushing

for package in `./packages.sh`; do
	[ "$(cd .. && git --git-dir=_git/$package/.git rev-list HEAD...origin/master --count)" != "0" ] && echo "$package"
done
