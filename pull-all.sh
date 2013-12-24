threads=0
maxthread=10
for package in `./packages.sh`; do
	./git.sh $package pull &
	threads="$((threads + 1))"
	[ "$((threads % maxthread))" == "0" ] && wait
done
