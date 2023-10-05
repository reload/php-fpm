#!/usr/bin/env bash

# Ensure Blackfire is only enabled if we have the necessary configuration.
set -e

if [ -n "${BLACKFIRE_CLIENT_ID}" ] && [ -n "${BLACKFIRE_CLIENT_TOKEN}" ]; then
	sudo docker-php-ext-enable-blackfire
fi
