@echo off
rem clone a package (or all packages) from github, or list uncloned packages

if [%1] == [] goto usage
if [%1] == [--all] goto clone_all
if [%1] == [--list] goto list_uncloned
if not exist _git/%1.exclude goto unknown_package
if exist _git/%1/.git/ goto already_cloned

md _git\%1
set GIT_DIR=_git/%1/.git

git init
git config --local core.worktree ../../..
git config --local core.excludesfile _git/%1.exclude
md _git\%PROJECT%\.git\hooks\
copy /Y _git\pre-commit  _git\%PROJECT%\.git\hooks\ >nul
copy /Y _git\post-commit _git\%PROJECT%\.git\hooks\ >nul
git remote add origin ssh://git@github.com/luapower/%1.git
git fetch
git branch --track master origin/master
git checkout

proj %1
goto end

:clone_all
for /f "delims=" %%p in ('clone --list') do clone %%p
goto end

:list_uncloned
for %%f in (_git/*.exclude) do call :check_uncloned %%f
goto end

:check_uncloned
set str=%1
set str=%str:.exclude=%
if not exist _git/%str%/.git echo %str%
goto end

:usage
echo.
echo USAGE:
echo    %0 ^<package^>        clone a package
echo    %0 --list           list uncloned packages
echo    %0 --all            clone all packages
echo.
goto end

:unknown_package
echo.
echo ERROR: unknown package %1
goto usage

:already_cloned
echo.
echo ERROR: %1 already cloned
goto usage


:end
