# fetch & merge all projects into the release repo

export HOME="$USERPROFILE"

release_dir=../lua-files-release
repos_dir=../lua-files-git/git-repos # relative to release_dir

[ -d "$release_dir" ] || {
	mkdir -p "$release_dir"
	(
		cd "$release_dir"
		git init
		echo "" > .gitignore
		git add .gitignore
		git commit -m "init"
		got rm .gitignore
		git commit -m "init"
	)
}

packages="$(./packages.sh)"
cd "$release_dir"
for package in $packages; do
	[ "$(git remote | grep ^$package\$)" ] || {
		git remote add $package \
			"$repos_dir/$package" #ssh://git@github.com/capr/$package
	}
	git fetch $package
	git merge $package/master
done

git push
