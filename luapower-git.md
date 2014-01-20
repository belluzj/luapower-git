---
project: luapower-git
tagline: Git workflow for luapower
---

## What?

An automated way for downloading, managing and building luapower packages.

## Why not just use git directly?

Mainly because luapower packages need to be overlaid over a single directory (all Lua modules from all packages
must be in the same directory) but git repositories want to have their own separate directories by default.

## How?

First, let's git it:

	git clone ssh://git@github.com/luapower/luapower-git luapower
	cd luapower

This gets us the `clone` command (among others) which allows us to clone luapower packages easily.
Let's use it to clone the dependencies needed for the `luapower` command (described below):

	clone lfs
	clone glue
	clone tuple

> NOTE: In Linux, the command is `./clone.sh`.

## Package management

---------------------- ------------------------------------------------
`clone --list`         list available (not cloned) packages
`clone <package>`      clone a package
`clone --all`          clone all available packages
`remove --list`        list local (cloned) packages
`remove <package>`     remove a package
---------------------- ------------------------------------------------

## The `luapower` command

This is a powerful command that extracts and aggregates data from the luapower environment and gives
detailed information about packages, modules and documentation. It can give accurate information about dependencies
between modules and packages because it actually loads the module and tracks `require` calls, and then it
integrates that information with the information about packages.

It is also used for keeping the package database on luapower.com up to date, along with the navigation tree
and the module/package dependency lists.

So do check it out. Type `luapower` for usage.

## Building all the C libraries in one shot

	build-all

This builds all packages that have a build script in the right order.

## Module development

> This section is only interesting if you wish to get involved in developing luapower modules.

Git commands can be invoked from the work tree by passing `--git-dir=_git/<package>/.git` to git,
or by setting the environment variable `GIT_DIR`. To ease the pain, the `proj` command can be used.

---------------------- ------------------------------------------------
`proj`                 list cloned repos
`proj <project>`       make git "track" a specific repo (i.e. set `GIT_DIR`)
`modified`             show modified files across all repos
`unpushed`             show unpushed repos
`untracked`            show untracked files (takes a while)
`on-all <cmd ...>`     execute a command for each repo, each time setting `GIT_DIR` (eg. `on-all git status`)
---------------------- ------------------------------------------------

