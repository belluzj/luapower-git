@echo off
rem uninstall a package: remove all the files, any empty directories left behind and the git repo.
rem TODO: remove empty directories

if [%1] == [] goto usage

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

:usage
echo usage: %0 ^<package^>
goto end

:end
