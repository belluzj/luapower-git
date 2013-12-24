# git wrapper that works in the worktree of a package

package="$1"; shift; [ "$package" ] || exit 1
basedir="$(cd "$(dirname "$0")"; pwd)"
gitdir="$basedir/git-repos/$package/.git"
[ -d "$gitdir" ] || exit 1
filesdir="$basedir/../lua-files"

export HOME="$USERPROFILE"
cd "$filesdir"
git --work-tree="$filesdir" --git-dir="$gitdir" "$@"
