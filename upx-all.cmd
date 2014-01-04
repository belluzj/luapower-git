@echo off
rem compress all windows binaries
rem TIP: get upx from http://upx.sourceforge.net/download/upx309w.zip

cd ../bin/mingw32
upx -q *.dll *.exe lanes/*.dll
