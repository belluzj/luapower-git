@echo off
rem clone a package from github

if [%1] == [] goto usage
if not exist _git/%1.exclude goto unknown_package
if exist _git/%1/.git/ goto already_cloned

md _git\%1

set GIT_DIR=_git/%1/.git
git init
git config --local core.worktree ../../..
git config --local core.excludesfile _git/%1.exclude
copy /Y _git\pre-commit _git\%PROJECT%\.git\hooks\pre-commit >null
git remote add origin ssh://git@github.com/luapower/%1.git
git fetch
git branch --track master origin/master
git checkout

proj %1
goto end


:usage
echo usage: %0 ^<package^>
goto end

:unknown_package
echo unknown package %1
goto end

:already_cloned
echo %1 already cloned
goto end


:end
