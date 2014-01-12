@echo off
rem print project version
set "spaces=                                           "
set "line=%PROJECT%%spaces%"
<nul set /p =%line:~0,16%
call git --git-dir=%GIT_DIR% describe --tags --long --dirty --always
