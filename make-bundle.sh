# fetch & merge all projects into the bundle repo

export HOME="$USERPROFILE"

bundle_dir=../lua-files-bundle
repos_dir=../lua-files-git/git-repos # relative to bundle_dir

[ -d "$bundle_dir" ] || {
	mkdir -p "$bundle_dir"
	(
		cd "$bundle_dir"
		git init
		echo "" > .gitignore
		git add .gitignore
		git commit -m "init"
		got rm .gitignore
		git commit -m "init"
	)
}

packages="$(./packages.sh)"
cd "$bundle_dir"
for package in $packages; do
	[ "$(git remote | grep ^$package\$)" ] || {
		git remote add $package \
			"$repos_dir/$package" #ssh://git@github.com/capr/$package
	}
	git fetch $package
	git merge $package/master
done

git push
