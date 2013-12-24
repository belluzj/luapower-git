
export HOME="$USERPROFILE"

for package in `./packages.sh`; do
	(
		echo " ~~~ $package ~~~ "
		cd git-repos/$package
		git add -A
		git commit -m "changed binary paths in build scripts"
		git push
	)
done
