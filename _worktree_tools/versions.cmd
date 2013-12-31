@echo off
rem print version info for all projects

set _PROJECT=%PROJECT%

for /F "tokens=* delims= " %%p in ('proj') do call :loopbody %%p
goto :eof

:loopbody
set PROJECT=%1
set "spaces=                                           "
set "line=%PROJECT%%spaces%"
<nul set /p =%line:~0,16%
call git describe --tags --long --dirty --always

:eof
set PROJECT=%_PROJECT%
