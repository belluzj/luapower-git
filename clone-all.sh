# clone all projects from github

for package in `./packages.sh`; do
	./clone.sh $package
done
