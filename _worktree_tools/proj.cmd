@echo off
rem set git to track a project or to list available projects.
rem also called from other scripts to get a list all projects.

if [%1] == [] goto list_projects else goto set_project

:set_project
	set GIT_DIR=_git/%1/.git
	echo tracking %1
	echo ------------------
	prompt [%1] $P$G
	call git ls-files
goto end

:list_projects
	for /d %%f in (_git/*) do if exist _git/%%f/.git echo %%f
goto end

:end
