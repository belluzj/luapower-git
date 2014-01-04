@echo off
rem check unpushed files in all projects

:begin
	for /F "tokens=* delims= " %%p in ('proj') do call :count %%p
goto end

:count
	set _PROJECT=%PROJECT%
	set PROJECT=%1
		for /f "delims=" %%i in ('git rev-list HEAD...origin/master --count') do if not "%%i" == "0" echo %PROJECT%
	set PROJECT=%_PROJECT%
goto end

:end
