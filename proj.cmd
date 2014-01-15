@echo off
rem set git to track a project or to list available projects.
rem also called from other scripts to get a list all projects.

if [%1] == [] goto list_projects

set PROJECT=%1
set GIT_DIR=_git/%1/.git
echo tracking %1
prompt [%1] $P$G
call git status -s
goto end

:list_projects
	for /d %%f in (_git/*) do if exist _git/%%f/.git echo %%f
	set PROJECT=
	set GIT_DIR=
	prompt $P$G
goto end

:end
