# show the status of all cloned packages

for package in `./packages.sh`; do
	cd ..
	git --git-dir=_git/$package/.git status -s
	cd _git
done
