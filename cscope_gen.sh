#!/bin/dash
rm cscope.*
find ./ -path "./out" -prune \
	-o -path "./kernel*" -prune \
	-o -name '*.py' \
	-o -name '*.java' \
	-o -iname '*.[CH]' \
	-o -name '*.cpp' \
	-o -name '*.cc' \
	-o -name '*.hpp'  \
	-o -name '*.mk' \
	-o -name '*.S' \
	-o -name '*.s' \
	-o -name '*.hal' \
	-o -name '*.xml' \
	-o -name '*.sh' \
	-o -name '*.json' \
	-o -name '*.mk' \
	-o -name '*.te' \
	-o -name '*.rc' \
	-o -name '*.policy' \
	-o -name '*.go' \
	> cscope.files

# -b: just build
# -q: create inverted index
cscope -b -q

