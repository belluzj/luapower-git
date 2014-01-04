@echo off
rem check unpushed files in all projects

for /F "tokens=* delims= " %%p in ('proj') do ^
for /f "delims=" %%i in ('git --git-dir=_git/%%p/.git rev-list HEAD...origin/master --count') do ^
if not "%%i" == "0" echo %%p
