# check what packages need pushing

for package in `./packages.sh`; do
	[ "$(./git.sh $package rev-list HEAD...origin/master --count)" != "0" ] && echo "$package"
done
