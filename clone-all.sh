# clone all projects from github

for package in `./known-packages.sh`; do
	./clone.sh $package
done
