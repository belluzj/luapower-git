# show the status of all cloned packages

for package in `./packages.sh`; do
	(cd "git-repos/$package" && git status -s)
done
