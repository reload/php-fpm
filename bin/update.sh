#!/usr/bin/env bash

mapfile -t versions < <(grep -E '^FROM .* AS php[0-9\.]+$' Dockerfile | cut -f 4 -d ' ')

for version in "${versions[@]}"; do
	image=$(grep "AS ${version}" Dockerfile | cut -f 2 -d ' ' | cut -f 1 -d @)
	new=$(docker manifest inspect -v "${image}" | jq -r '.[0].Ref' | sed -s 's#^docker\.io/\(library/\)\?##')

	sed -i "s#FROM .*AS ${version}#FROM ${new} AS ${version}#" Dockerfile
done
