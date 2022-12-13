#!/usr/bin/env bash

# Ensure Blackfire is only enabled if we have the necessary configuration.
set -e

if [ -n "${BLACKFIRE_SOCKET}" ]; then
	docker-php-ext-enable-blackfire
fi
