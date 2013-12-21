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

cd ../lua-files/csrc
for package in $packages; do
	echo " ~~~~ $package ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ "
	pushd $package
	./build-mingw32.sh || exit 1
	popd
done

