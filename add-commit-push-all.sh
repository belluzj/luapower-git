
export HOME="$USERPROFILE"

for package in `./packages.sh`; do
	(
		echo " ~~~ $package ~~~ "
		cd git-repos/$package
		git add -A
		git commit -m "added binaries back to their right paths"
		git push
	)
done
