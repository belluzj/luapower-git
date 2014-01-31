#!/bin/sh
# detect current platform
[ "$OSTYPE" = "msys" ] && platform=mingw32 || [ "$(uname -m)" == "x86_64" ] && platform=linux64 || platform=linux32
echo $platform
