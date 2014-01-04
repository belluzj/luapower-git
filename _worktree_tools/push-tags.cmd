@echo off
rem push tags to remote

for /F "tokens=* delims= " %%p in ('proj') do (
	echo ~~~ %%p ~~~
	git --git-dir=_git/%%p/.git push --tags
)
