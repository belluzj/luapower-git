# list all cloned packages
cd "$(dirname "$0")"
for f in *; do [ -d "$f/.git" -a "${f#_}" == "$f" ] && echo "$f"; done
