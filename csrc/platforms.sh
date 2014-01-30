
platforms() {
    for p in $1/build-*.sh; do
	p=${p#*/}
	p=${p%*.sh}
	p=${p#build-}
	echo $p
    done
}

for f in *; do
    [ -d "$f" ] && {
	echo "$f" $(platforms "$f")
    }
done