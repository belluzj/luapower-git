@echo off
rem check modified files in all projects

set _PROJECT=%PROJECT%

for /F "tokens=* delims= " %%p in ('proj') do call :loopbody %%p
goto :eof

:loopbody
set PROJECT=%1
call git status -s

:eof
set PROJECT=%_PROJECT%
