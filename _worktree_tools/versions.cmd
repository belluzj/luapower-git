@echo off
rem print version info a project or for all projects

if [%1] == [] goto list_versions
goto show_version

:list_versions
	for /F "tokens=* delims= " %%p in ('proj') do call :show_version %%p
goto end

:show_version
	set "spaces=                                           "
	set "line=%1%spaces%"
	<nul set /p =%line:~0,16%
	call git --git-dir=_git/%1/.git describe --tags --long --dirty --always
goto end

:end
