#!/bin/sh
# execute luajit from this directory on any platform.
[ "$OSTYPE" == "msys" ] && platform=mingw32 || platform=linux32
cd "$(dirname "$0")" && bin/$platform/luajit "$@"
