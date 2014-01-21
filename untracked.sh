#!/bin/sh
# show untracked files in all projects

tracked_files() {
	for project in `./proj.sh`; do
		git --git-dir=_git/$project/.git ls-files
	done | sort | uniq -u
}

root_files() {
	for f in *; do
		ext="${f##*.}"
		[ "$ext" != "$f" -o -d "$f" ] \
		&& [ "$ext" != "tmp" ] \
		&& [ "$ext" != "sh" ] \
		&& [ "$ext" != "cmd" ] \
		&& [ "${f#_}" = "$f" ] \
		&& [ "$f" != "luapower.lua" ] \
		&& [ "$f" != "luapower-git.md" ] \
		&& echo "$f"
	done
}

existing_files() {
	[ "$(root_files)" ] && \
		/usr/bin/find $(root_files) -type f -print | sort | uniq -u
}

rm -f untracked.*.tmp
tracked="untracked.tracked-$$.tmp"
existing="untracked.existing-$$.tmp"
trap "rm -f $tracked $existing" INT TERM EXIT # TODO: not working when SciTE kills the script
tracked_files > "$tracked"
existing_files > "$existing"
comm -23 "$existing" "$tracked"
