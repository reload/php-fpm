#!/usr/bin/env bash

set +e
status=0
trap '{ (( status++ )) ; }' ERR

linenumber=$(grep -n 'ARG php_enable_extensions' Dockerfile | cut -f 1 -d :)
for extension in $(grep 'ARG php_enable_extensions' Dockerfile | cut -f 2 -d = | tr --delete '"'); do
	grep -q -- "- ${extension}\$" README.md || (
		echo "::error file=Dockerfile,line=${linenumber}::PHP extension '${extension}' is not documented in README.md."
		exit 1
	)
done

start=$(grep -n '## PHP extensions' README.md | cut -f 1 -d :)
end=$(tail -n +$((start + 1)) README.md | grep -n '^##' | cut -f 1 -d : | head -n 1)
list=$(tail -n +$((start + 1)) README.md | head -n "${end}" | grep -- '^-' | sed 's/ *- *//')

for extension in $list; do
	linenumber=$(grep -nE " *- *${extension}" README.md | cut -f 1 -d :)
	(grep 'ARG php_enable_extensions' Dockerfile | grep -q "${extension}") || (
		echo "::error file=README.md,line=${linenumber}::PHP extension '${extension}' is not listed in Dockerfile."
		exit 1
	)
done

exit "${status}"
