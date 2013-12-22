# some packages depend upon one another at the binary level,
# that's why we hardcode the compilation list. we don't have time for fancy dep trees.
packages="\
md5
sha2
libb64
boxblur
vararg
struct
lpeg
nanojpeg
lua-cjson
luasocket
libunibreak
lfs
lanes
genx
giflib
clipper
zlib
minizip
libexif
chipmunk
hunspell
freetype
libpng
pixman
cairo
harfbuzz-ucdn
harfbuzz"

platform="$1"
[ "$platform" ] || {
	echo "usage: $0 <platform>"
	echo "       platforms: mingw32, linux32"
	exit 1
}

for package in $packages; do
	echo " ~~~~ $package ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ "
	./build.sh $package "$platform" || exit 1
done

./upx-all.sh
