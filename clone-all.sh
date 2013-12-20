# clone all projects from github

for package in `./list.sh`; do
	./clone.sh $package
done
