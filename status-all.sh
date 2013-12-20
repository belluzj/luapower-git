# show status of all cloned packages

for package in `./list.sh`; do
	echo "~~ $package ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	(cd "git-repos/$package" && git status -s)
done
