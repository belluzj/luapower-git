#!/bin/sh
# shortcut for git add, commit and push (example usage: `./on-all.sh ./acp.sh "minor changes"`)
[ "$1" ] || { echo "usage: $0 <commit message>"; exit 1; }

git add -A
git commit -m "$1"
git push
