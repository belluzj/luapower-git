# git add, commit and push all repos

[ "$HOME"] || export HOME="$USERPROFILE"

gitp() { git --git-dir=_git/$package/.git "$@"; }

for package in `./packages.sh`; do
	echo " ~~~ $package ~~~ "
	cd ..
	gitp add -A
	gitp commit -m "upgrade"
	# gitp tag -f `gitp describe --abbrev=0 --tags`
	[ "$(gitp rev-list HEAD...origin/master --count)" != "0" ] && \
		gitp push
	cd _git
done
