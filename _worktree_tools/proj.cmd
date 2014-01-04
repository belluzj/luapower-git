@echo off
rem set git wrapper to track a project, or list projects

if "%1"=="" goto list_projects else goto set_project

:set_project
set PROJECT=%1
rem we could have used `set GIT_DIR=%~dp0/_git/%PROJECT%/.git`
rem and removed the git wrapper but that doesn't work with msys-git 1.8.4 (maybe in the future).
echo tracking %PROJECT%
echo ------------------
prompt [%PROJECT%] $P$G
call git ls-files
goto :done

:list_projects
cd _git
call sh packages.sh
cd ..
goto :done

:done
