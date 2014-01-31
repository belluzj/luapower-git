---
project: luapower-git
tagline: git workflow for luapower
---

## What

Downloading and managing luapower packages the git way.

## Why not just use git directly?

Mainly because luapower packages need to be overlaid over the same directory, but you can't just git-clone multiple
repos over the same directory with git (for no reason- git-clone could and should totally allow you to do that).
Git _does_ support overlaying multiple repos over a common directory structure but that's [not trivial][clone.cmd]
to set up, and that is where [luapower-git] comes in.

## How

First, let's git it:

	> git clone https://github.com/luapower/luapower-git luapower
	> cd luapower

> The SSH url is `ssh://git@github.com/luapower/luapower-git`

This brings in the `clone` and `remove` commands:

	> clone

	USAGE:
		clone <package> [origin | url]    clone a package
		clone --list                      list uncloned packages
		clone --all                       clone all packages

> __NOTE:__ In Linux, the command is `./clone.sh`. They're all like that.

> __NOTE:__ To clone packages via SSH instead, edit `_git/luapower.baseurl` and replace the url there with `ssh://git@github.com/luapower/`

> __Tip:__ You can clone repos from any location, as long as they have the proper [directory layout][get-involved].

> __Tip:__ Remote origins can be labeled to avoid typing the full url every time when cloning.
Create a file named `_git/foo.baseurl`, write the base url (with traling slash) in it, and then clone
with `clone <package> foo`.

	> remove

	USAGE:
		remove <package>       remove a cloned package completely from the disk
		remove --list          list cloned packages

The rest is done via git, using the `proj` command to set the context (repo) in which git should operate.

   > proj foo
	[foo] > git ls-files

	foo.lua
	foo.md

	[foo] > proj bar
	[bar] > git pull
	...
	[bar] > proj baz
	[baz] > git pull
	...

> `proj` is but a glorified wrapper for setting the env var `GIT_DIR=_git/<package>/.git`, which allows us to use
git as normal without leaving the work-tree.

## The `luapower` command

This is a powerful command that extracts and aggregates data from the luapower environment and gives
detailed information about packages, modules and documentation. It can give accurate information about dependencies
between modules and packages because it actually loads the module and tracks `require` calls, and then it
integrates that information with the information about packages.

It is also used for generating the package database on luapower.com, along with the the dependency lists
you see on each module's page.

The `luapower` command is a Lua script that depends on [luajit], [lfs], [glue] and [tuple] so let's clone these first:

	> clone luajit
	> clone lfs
	> clone glue
	> clone tuple

The rest you can learn from the tool itself:

	> luapower

	USAGE: luapower <command> ...

	HELP

		help                           this screen

	PACKAGES

		packages                       list installed packages
		known                          list all known package
		left                           list not yet installed packages

	PACKAGE INFO

		describe <package>             describe a package
		type [package]                 package type
		ver [package]                  current git version
		tags [package]                 git tags
		tag [package]                  current git tag
		files [package]                tracked files
		docs [package]                 docs
		modules [package]              modules
		scripts [package]              scripts
		mtree [package]                module tree
		mtags [package [module]]       module info
		platforms [package]            supported platforms
		ctags [package]                C package info

	CHECKS

		check [package]                consistency checks
		trackable                      trackable files
		multitracked                   files tracked by multiple packages
		untracked                      files not tracked by any package

	DATABASE

		update-db [package]            update _site/packages.json
		update-toc [package]           update _site/toc.md
		update [package]               update both _site/packages.json and _site/toc.md

	DEPENDENCIES

		requires <module>              direct module requires
		rall <module>                  direct and indirect module requires
		rtree <module>                 module require log tree
		rext <module>                  direct-external module requires
		pall <module>                  direct and indirect package dependencies
		pext <module>                  direct-external package dependencies
		ppall [package]                direct and indirect package dependencies
		ppext [package]                direct-external package dependencies
		cdeps [package]                direct and indirect C dependencies
		rrev <module>                  all modules that require a module

	The `package` arg defaults to the env var PROJECT, as set by the `proj` command,
	and if that is not set, it defaults to `--all`, meaning all packages.


## Building all C libraries

	> build-all

This builds all packages that have a build script in the right order (pretty fast too).

## Module development

Some handy git wrappers for tracking changes across the entire repo collection:

---------------------- ------------------------------------------------
`> modified`           list modified files across all repos
`> unpushed`           list unpushed repos
`> untracked`          list untracked files (takes a while)
---------------------- ------------------------------------------------


[clone.cmd]:   http://github.com/luapower/luapower-git/blob/master/clone.cmd
