@echo off
rem uninstall a package: remove all the files, any empty directories left behind and the git repo.

if [%1] == [] goto usage
if [%1] == [--list] goto list_cloned
if not exist _git/%1/.git/ goto not_cloned

for /f "delims=" %%i in ('git --git-dir=_git/%1/.git ls-files') do call :remove_file %%i
for /f "delims=" %%i in ('git --git-dir=_git/%1/.git ls-files') do call :remove_empty_dir %%i
rd /S /Q _git\%1
goto end

:remove_file
set FILE=%1
set FILE=%FILE:/=\%
del %FILE%
goto end

:remove_empty_dir
set FILE=%~dp1
set FILE=%FILE:/=\%
rd %FILE% 2>nul
goto end

:not_cloned
echo.
echo ERROR: unknown package %1
goto usage

:list_cloned
for /d %%f in (_git/*) do echo %%f
goto end

:usage
echo.
echo USAGE:
echo    %0 ^<package^>       remove a cloned package completely from the disk
echo    %0 --list          list cloned packages
echo.
goto end


:end
