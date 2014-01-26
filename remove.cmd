@echo off
setlocal
rem uninstall a package: remove all the files, any empty directories left behind and the git repo.

if [%1] == [] goto usage
if [%1] == [--list] goto list_cloned
if not exist _git/%1/.git/ goto not_cloned

for /f "delims=" %%i in ('git --git-dir=_git/%1/.git ls-files') do call :remove_file %%i
for /f "delims=" %%i in ('git --git-dir=_git/%1/.git ls-files') do call :remove_empty_dir %%i
rd /S /Q _git\%1
goto end

:remove_file
set file=%1
set file=%file:/=\%
del %file%
goto end

:remove_empty_dir
set file="%~dp1"
set file=%file:/=\%
rd %file% 2>nul
goto end

:not_cloned
echo.
echo ERROR: unknown package %1
goto usage

:list_cloned
for /d %%f in (_git/*) do call :check_cloned %%f
goto end

:check_cloned
if exist _git/%1/.git/ echo %1
goto end

:usage
echo.
echo USAGE:
echo    %0 ^<package^>       remove a cloned package completely from the disk
echo    %0 --list          list cloned packages
echo.
goto end


:end
