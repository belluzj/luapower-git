gitdir="$PWD"
cd ../.. && git --git-dir="$gitdir/.git" "$@"
