@echo off
rem set git wrapper to track a project, or list projects

if "%1"=="" goto list_projects else goto set_project

:set_project
set PROJECT=%1
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
