#!/usr/bin/env bash

set -euo pipefail

mapfile -t versions < <(grep -E '^FROM .* AS php[0-9\.]+$' Dockerfile | cut -f 4 -d ' ')

for version in "${versions[@]}"; do
	image=$(grep "AS ${version}" Dockerfile | cut -f 2 -d ' ' | cut -f 1 -d @)
	new=$(docker buildx imagetools inspect --raw "${image}" | jq -r '.manifests[0].digest')
	sed -i "s#FROM .*AS ${version}#FROM ${image}@${new} AS ${version}#" Dockerfile
done
