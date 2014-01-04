@echo off
rem find git.exe in PATH and run it with --git-dir

:begin
	if "%PROJECT%"=="" goto no_project
	for %%i in (git.exe) do call %%~$PATH:i --git-dir=_git\%PROJECT%\.git %*
goto end

:no_project
	echo not tracking any project.
	echo type ^`proj ^<project^>^` first to track a project.
	echo type ^`proj^` to list all projects.
goto end

:end
