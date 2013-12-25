# git wrapper that can be called from a git-dir but which
# actually executes git from the project's work-tree with --git-dir option.

gitdir="$PWD"
cd ../.. && git --git-dir="$gitdir/.git" "$@"
