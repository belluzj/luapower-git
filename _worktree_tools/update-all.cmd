@echo off
rem git add, commit and push all repos with a commit message (good for bulk updates to documentation)

if [%1] == [] goto usage

for /F "tokens=* delims= " %%p in ('proj') do (
echo ~~~ %%p ~~~
git --git-dir=_git/%%p/.git add -A
git --git-dir=_git/%%p/.git commit -m %1
for /f "delims=" %%i in ('git --git-dir=_git/%%p/.git rev-list HEAD...origin/master --count') do ^
if not "%%i" == "0" git --git-dir=_git/%%p/.git push
)
goto end

:usage
	echo usage: %0 ^<commit-message^>
goto end

:end
