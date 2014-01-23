@echo off
rem clone a package (or all packages) from origin, or list uncloned packages

if [%1] == [] goto usage
if [%1] == [--all] goto clone_all
if [%1] == [--list] goto list_uncloned

if not exist _git/%1.exclude goto unknown_package
if exist _git/%1/.git/ goto already_cloned
if [%2] == [] (set _origin=default) else (set _origin=%2)
if exist _git/%_origin%.origin (
	for /f "delims=" %%s in (_git/%_origin%.origin) do set _url=%%s/%1
) else (set _url=%_origin%)

md _git\%1
set GIT_DIR=_git/%1/.git

git init
git config --local core.worktree ../../..
git config --local core.excludesfile _git/%1.exclude
git remote add origin %_url%
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
set _s=%1
set _s=%_s:.exclude=%
if not exist _git/%_s%/.git echo %_s%
goto end

:usage
echo.
echo USAGE:
echo    %0 ^<package^> ^[origin ^| url^]    clone a package
echo    %0 --list                      list uncloned packages
echo    %0 --all                       clone all packages
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
