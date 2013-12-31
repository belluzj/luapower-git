cd ..
for f in *.lua; do
	f="${f%.*}" # strip extension
	[ "${f%_test*}" == "$f" \
		-a "${f%_demo*}" == "$f" \
		-a "${f%_benchmark*}" == "$f" \
		-a "${f%_app*}" == "$f" \
		-a "${f#fbclient_}" == "$f" \
	] && \
		printf "%-20s %s\n" "$f" "$(cd _docs; ./dependencies.sh "$f")"
done
