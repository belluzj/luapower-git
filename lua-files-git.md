---
project: lua-files-git
tagline: Git workflow for lua-files
---

## What?

A way to git-clone individual [lua-files](lua-files.html) packages so that
you download only what you need from lua-files.

## Why not just use git directly?

Because lua-files packages need to be overlaid over a single directory
but git repositories work in their own separate directories by default.

## How?

	mkdir lua-files
	cd lua-files
	git clone ssh://git@github.com/capr/lua-files/git _git
	cd _git
	sh clone.sh <package1>
	sh clone.sh <package2>
	...

> NOTE: These shell scripts work in Windows too if you have MSYS in your PATH.

This way the packages are all cloned into `lua-files` (one dir above `_git`).
They all share the same `work-tree` which is `lua-files`,
but they maintain a separate `git-dir`, at `_git/<package>/.git`.
Git commands can be invoked from the work-tree by passing `--git-dir=_git/<package>/.git`.
Some (but not all) git commands can also be invoked from `_git/<package>` without the need
to pass additional options.

------------------------------------ ------------------------------------
./packages.sh                        list packages
./clone.sh <package>                 clone a package in the parent dir
./clone-all.sh                       clone all packages
------------------------------------ ------------------------------------

