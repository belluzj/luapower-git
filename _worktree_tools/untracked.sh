# show untracked files in all projects

packages="$(cd _git; ./packages.sh)"

tracked_files() {
	for project in $packages; do
		git --git-dir=_git/$project/.git ls-files
	done | sort | uniq -u
}

root_files() {
	for f in *; do
		[[ "$f" =~ "^_" ]] || \
		[[ "$f" =~ "\\.sh\$" ]] || \
		[[ "$f" =~ "\\.cmd\$" ]] || \
		echo "$f"
	done
}

existing_files() {
	/bin/find $(root_files) -type f -print | sort | uniq -u
}

tracked="$(mktemp)"; tracked_files > "$tracked"
existing="$(mktemp)"; existing_files > "$existing"

comm -23 "$existing" "$tracked"

rm "$tracked"
rm "$existing"

#TODO: WTF moment
#echo; echo
#tracked_files | grep "bin/mingw32/jit/WHAT"
#existing_files | grep "bin/mingw32/jit/WHAT"
