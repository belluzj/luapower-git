@echo off
rem print version info a project or for all projects

if "%1" == "" goto list_versions
goto show_version

:list_versions
	for /F "tokens=* delims= " %%p in ('proj') do call :show_version %%p
goto end

:show_version
	set _PROJECT=%PROJECT%
	set PROJECT=%1
	set "spaces=                                           "
	set "line=%PROJECT%%spaces%"
	<nul set /p =%line:~0,16%
	call git describe --tags --long --dirty --always
	set PROJECT=%_PROJECT%
goto end

:end
