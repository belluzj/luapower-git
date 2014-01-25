@echo off
rem perform a command for each project in the context of PROJECT and GIT_DIR variables

if [%1] == [] goto usage

set _PROJECT=%PROJECT%
set _GIT_DIR=%GIT_DIR%
for /F "tokens=* delims= " %%p in ('proj') do (
set PROJECT=%%p
set GIT_DIR=_git/%%p/.git
call %*
)
set PROJECT=%_PROJECT%
set GIT_DIR=%_GIT_DIR%
set _PROJECT=
set _GIT_DIR=
goto end

:usage
	echo.
	echo USAGE: %0 ^<command args...^>
	echo.
	echo Calls ^<command args ...^> for each project, with GIT_DIR and PROJECT env vars
	echo set appropriately every time.
	echo.
goto end

:end
