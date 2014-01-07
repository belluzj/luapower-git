---
project: luapower-git
tagline: Git workflow for luapower
---

## What?

A way to download and manage luapower packages using git.

## Why not just use git directly?

Because looking for modules on github and copy-pasting git URLs into the command line is boring.
And because luapower packages need to be overlaid over a single directory but git repositories
want to have their own separate directories by default.

## How?

	mkdir luapower
	cd luapower
	git clone ssh://git@github.com/luapower/luapower-git _git
	cd _git
	./known-packages.sh
	./clone.sh <package>
	...

This way the packages are all cloned into `luapower` (one dir above `_git`).
They all share the same git worktree which is `luapower`,
but they maintain a separate git dir, at `_git/<package>/.git`.

## Package management

--------------------------- ----------------------------------------
./known-packages.sh         list all available packages
./packages.sh               list cloned packages
./clone.sh <package>        clone a package in the parent dir
./clone-all.sh              clone all packages
./build-all.sh              build all C packages in the right order
--------------------------- ----------------------------------------

> NOTE: These shell scripts work in Windows too if you have MSYS in your PATH. Use the cmd wrappers then.

## Module development

Git commands can be invoked from the work tree by passing `--git-dir=_git/<package>/.git` to git,
or by setting the environment variable `GIT_DIR`. To ease the pain, copy the scripts from `_worktree_tools`
into the worktree and use those, they are very easy to use.
