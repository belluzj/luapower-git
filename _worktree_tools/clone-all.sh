# clone all projects from github

i=0
for package in `./known-packages.sh`; do
	i=$((i + 1))
	./clone.sh $package &
	[ $((i % 8)) == 0 ] && wait
done
