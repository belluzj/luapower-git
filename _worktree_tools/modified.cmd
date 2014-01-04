@echo off
rem check modified files in all projects

for /F "tokens=* delims= " %%p in ('proj') do ^
call git --git-dir=_git/%%p/.git status -s
