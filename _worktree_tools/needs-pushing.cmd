@rem list repo if it needs pushing
@for /f "delims=" %%i in ('git --git-dir=%GIT_DIR% rev-list HEAD...origin/master --count') do if not "%%i" == "0" echo %%p
