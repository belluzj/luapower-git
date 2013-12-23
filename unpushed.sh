# check what packages need pushing

for package in `./packages.sh`; do
	(cd "git-repos/$package" && [ "$(git rev-list HEAD...origin/master --count)" != "0" ] && echo "$package")
done
