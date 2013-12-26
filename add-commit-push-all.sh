# git add, commit and push all repos

[ "$HOME"] || export HOME="$USERPROFILE"

for package in `./packages.sh`; do
	echo " ~~~ $package ~~~ "
	cd ..
	git --git-dir=_git/$package/.git add -A
	git --git-dir=_git/$package/.git commit -m "upgrade"
	[ "$(git --git-dir=_git/$package/.git rev-list HEAD...origin/master --count)" != "0" ] && \
		git --git-dir=_git/$package/.git push
	cd _git
done
