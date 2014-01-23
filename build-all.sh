# build all C packages in order

indep_packages="
blur
chipmunk
clipper
expat
fribidi
genx
giflib
glut
hunspell
libb64
libexif
libjpeg
libunibreak
luajit
md5
nanojpeg
pixman
pmurhash
sha2
ucdn
zlib
freetype
"

luajit_packages="
lfs
lpeg
cjson
socket
struct
vararg
lanes
wluajit
"

zlib_packages="
minizip
libpng
"

png_packages="
hpdf
cairo
"

ucdn_packages="
harfbuzz
"

packages="$indep_packages $luajit_packages $zlib_packages $png_packages $ucdn_packages"

[ "$OSTYPE" = "msys" ] && platform=mingw32 || platform=linux32

mkdir -p bin/linux32 bin/linux32/clib bin/linux32/lua

for package in $packages; do
	[ -f "csrc/$package/build-$platform.sh" ] && (
		echo
		echo "$package --------------------------------------------"
		echo
		cd "csrc/$package" && ./build-$platform.sh
	)
done
