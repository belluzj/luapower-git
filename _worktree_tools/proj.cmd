@echo off
rem set git wrapper to track a project or to list available projects.
rem also called from other scripts to get a list all projects.

if "%1" == "" goto list_projects else goto set_project

:set_project
	set PROJECT=%1
	rem we could have used `set GIT_DIR=%~dp0/_git/%PROJECT%/.git`
	rem and removed the git wrapper but that doesn't work with msys-git 1.8.4 (maybe in the future).
	echo tracking %PROJECT%
	echo ------------------
	prompt [%PROJECT%] $P$G
	call git ls-files
goto end

:list_projects
	call sh _git/cloned-packages.sh
goto end

:end
