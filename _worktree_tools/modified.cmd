@echo off
rem check modified files in all projects

:begin
	for /F "tokens=* delims= " %%p in ('proj') do call :status %%p
goto end

:status
	set _PROJECT=%PROJECT%
	set PROJECT=%1
		call git status -s
	set PROJECT=%_PROJECT%
goto end

:end
