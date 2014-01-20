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
	echo usage: %0 ^<command args...^>
goto end

:end
