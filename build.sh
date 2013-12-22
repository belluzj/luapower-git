package="$1"
platform="$2"
[ "$package" -a "$platform" ] || {
	echo "usage: $0 <package> <platform>"
	echo "       platforms: mingw32, linux32"
	exit 1
}

cd ../lua-files/csrc/$package
./build-$platform.sh
