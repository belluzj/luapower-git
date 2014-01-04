# list all known packages
cd "$(dirname "$0")"
ls *.exclude -1 | sed 's/\.exclude//'
