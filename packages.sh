# list all cloned packages
cd "$(dirname "$0")"
for f in *; do [ -d "$f/.git" ] && echo "$f"; done
