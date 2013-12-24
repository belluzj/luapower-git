# show the status of all cloned packages

for package in `./packages.sh`; do
	./git.sh $package status -s
done
