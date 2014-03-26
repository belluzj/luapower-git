#!/bin/sh
# detect platform
[ "$PROCESSOR_ARCHITECTURE" = "AMD64" ] && platform=mingw64 || {
	[ "$OSTYPE" = "msys" ] && platform=mingw32 || {
		[ "$(uname -m)" = "x86_64" ] && a=64 || a=32
		[ "${OSTYPE#darwin}" != "$OSTYPE" ] && platform=osx$a || platform=linux$a
	}
}
echo $platform
