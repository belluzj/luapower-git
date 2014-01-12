# build all C packages in order
set -e # break on errors

[ "$OSTYPE" == "msys" ] && platform=mingw32 || platform=linux32

indep_packages="
luajit
chipmunk
clipper
fribidi
genx
giflib
hpdf
hunspell
libb64
libexif
libjpeg
libunibreak
md5
minizip
nanojpeg
pixman
pmurhash
sha2
ucdn
zlib
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
libpng
freetype
cairo
"

ucdn_packages="
harfbuzz
"

packages="$indep_packages $luajit_packages $zlib_packages $ucdn_packages"

for package in $packages; do
	[ -f "csrc/$package/build-$platform.sh" ] && (
		cd "csrc/$package" && ./build-$platform.sh
	)
done
