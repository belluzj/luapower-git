# commit/push all cloned packages with the same message

export HOME="$USERPROFILE"

for package in `./list.sh`; do
	echo "~~ $package ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	pushd "git-repos/$package"
	git add -A
	git commit -m "upgrade" && git push
	popd
done
