#!/bin/sh
# build a package for the host platform using our own gcc and g++ wrappers

[ "$1" ] && package="$1" || { echo "usage: $0 <package> | --all [gcc / g++ options...]"; exit 1; }
shift

platform="$(./platform.sh)"
export PLATFORM=$platform
export BINDIR="$PWD/../bin/$platform"
export GCC="$(which gcc)"
export GPP="$(which g++)"
export PATH="$PWD:$PATH" # use local gcc and g++ wrappers

build() {
    [ -f $package/build-$platform.sh ] || return
    cd $package
    ./build-$platform.sh "$@"
    cd ..
}

[ "$package" == "--all" ] && {
    for package in `./packages.sh`; do
	echo
	echo "$package --------------------------------------------"
	echo
	build $package "$@"
    done
    exit
}

build $package "$@"
