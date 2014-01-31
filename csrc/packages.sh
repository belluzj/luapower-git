#!/bin/sh
# list packages in the order in which they should be built

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

for p in $packages; do
    echo $p
done
