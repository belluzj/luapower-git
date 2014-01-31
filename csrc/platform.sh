#!/bin/sh
# detect current platform
[ "$OSTYPE" = "msys" ] && platform=mingw32 || {
  [ "${OSTYPE#darwin}" != "$OSTYPE" ] && platform=osx64 || {
    [ "$(uname -m)" = "x86_64" ] && platform=linux64 || platform=linux32
  }
}
echo $platform
