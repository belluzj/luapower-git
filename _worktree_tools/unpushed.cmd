@echo off
rem check unpushed files in all projects

set _PROJECT=%PROJECT%

for /F "tokens=* delims= " %%p in ('proj') do call :loopbody %%p
goto :eof

:loopbody
set PROJECT=%1
for /f "delims=" %%i in ('git rev-list HEAD...origin/master --count') do ^
if not "%%i" == "0" echo %PROJECT%

:eof
set PROJECT=%_PROJECT%

