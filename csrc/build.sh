#!/bin/sh
# build wrapper that allows using a different compiler and adding C/C++ flags.

[ "$1" ] && package="$1" || { 
    echo "usage: [CC=...] [CXX=...] [CFLAGS=...] [CXXFLAGS=...] [PLATFORM=...] $0 <package> | --all"
    exit 1 
}
shift

[ "$PLATFORM" ] || PLATFORM="$(./platform.sh)"
[ "$CC" ] || CC="$(which gcc)"
[ "$CXX" ] || CXX="$(which g++)"

export CC_1="$CC"
export CXX_1="$CXX"
export CFLAGS_1="$CFLAGS"
export CXXFLAGS_1="$CXXFLAGS"
export PATH="$PWD:$PATH" # use local gcc and g++ wrappers

build() {
    [ -f $package/build-$PLATFORM.sh ] || return
    cd $package
    ./build-$PLATFORM.sh "$@"
    cd ..
}

[ "$package" == "--all" ] && {
    echo "Building all for $PLATFORM..."
    echo
    for package in `./packages.sh`; do
	echo
	echo "$package --------------------------------------------"
	echo
	build $package "$@"
    done
    exit
}

build $package "$@"
