@echo off
setlocal
rem perform a command for each project in the context of PROJECT and GIT_DIR variables

if [%1] == [] goto usage

for /F "tokens=* delims= " %%p in ('proj') do ^
for /f "delims=" %%i in ('git --git-dir=_git/%%p/.git status -s') do ^
if not [%%i] == [] (
set PROJECT=%%p
set GIT_DIR=_git/%%p/.git
call %*
)
goto end

:usage
	echo usage: %0 ^<command args...^>
goto end

:end
