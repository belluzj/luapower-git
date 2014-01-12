@echo off
rem shortcut for git add, commit and push (example usage: `on-all acp "minor changes"`)
if [%1] == [] goto usage

git add -A
git commit -m %1
git push
goto end

:usage
echo usage: %0 ^<commit message^>
goto end

:end
