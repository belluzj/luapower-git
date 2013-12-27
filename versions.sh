# list the most recent git tag on current branch for each package

for package in `./packages.sh`; do
	[ -d "$package/.git" ] && {
		tag=`git --git-dir=$package/.git describe --tags --long --dirty --always`
		printf "%-16s  %s\n" "$package" "$tag"
	}
done

