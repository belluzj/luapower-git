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
to set up, and that is where luapower-git comes in.

## How

First, let's git it:

	> git clone https://github.com/luapower/luapower-git luapower
	> cd luapower

> The ssh url is `ssh://git@github.com/luapower/luapower-git`

This brings in the `clone` and `remove` commands:

	> clone

	USAGE:
		clone <package> [origin | url]    clone a package
		clone --list                      list uncloned packages
		clone --all                       clone all packages

> __NOTE:__ In Linux, the command is `./clone.sh`. They're all like that.

> __NOTE:__ To clone packages via ssh instead, you can either a) edit `_git/luapower.baseurl`
and replace the url there with `ssh://git@github.com/luapower/`, or b) configure git to replace
urls on-the-fly with `git config --global url."ssh://git@github.com/luapower/".insteadOf https://github.com/luapower/`.

> __Tip:__ You can clone in luapower packages from any location, not just github, as long as they have
the proper [directory layout][get-involved]. These locations can even be labeled to avoid typing the full url
every time when cloning. Create a file named `_git/xyz.baseurl`, write the base url (with traling slash) in it,
and then clone it by typing `clone <package> xyz`.

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

> `proj` is just a glorified wrapper for setting the env var `GIT_DIR=_git/<package>/.git`, which allows us to use
git (for a specific package) without leaving the (shared) work-tree.

## Building all C libraries

	> cd csrc
	> build --all

This builds all the packages that have a build script for the current platform, in the right order (pretty fast too).
You need to set up a building [environment][building] for this to work.

## Updating all packages

	> on-all git pull

## Module development

### Creating a new package

1. Create `_git/<package.origin>` and write in it the git url where you plan to upload your package.
2. Run `clone <package>`. It will fail since there's no repo at that url, but it will create your local repository.
3. Add your files, which can be anywhere in the luapower tree. Refer to [get-involved] if you want to stick to the
conventions, but you don't have to, unless you want to add your module to luapower.com.
4. Type `proj <package>` and then add/commit/push with the usual `git add`, `git commit` and `git push` commands.
To avoid seeing other modules' files as untracked, create a file named `<package>.exclude`, which is the .gitignore
file for your package.

### Updating multiple packages

Here's a few handy git wrappers for tracking changes across the entire repo collection:

	> modified           ; list modified files across all repos
	> unpushed           ; list unpushed repos
	> untracked          ; list untracked files (takes a while)

## Module publishing

Refer to [get-involved].


[clone.cmd]:   http://github.com/luapower/luapower-git/blob/master/clone.cmd
