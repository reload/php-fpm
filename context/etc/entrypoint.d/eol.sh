#!/usr/bin/env bash

TODAY=$(date +%Y-%m-%d)
SUPPORT=$(jq -r .support /etc/eol.json)
EOL=$(jq -r .eol /etc/eol.json)

if [[ "$TODAY" > "$SUPPORT" ]]; then
	echo "" >&2
	echo "###############################################" >&2
	echo "##" >&2
	echo "## This version of PHP is unsupported. Please upgrade to a supported version." >&2
	echo "##" >&2
	echo "###############################################" >&2
	echo "" >&2
fi

if [[ "$TODAY" > "$EOL" ]]; then
	echo "" >&2
	echo "###############################################" >&2
	echo "##" >&2
	echo "## This version of PHP has reached end of life and no longer receives security updates. Please upgrade to a supported version." >&2
	echo "##" >&2
	echo "###############################################" >&2
	echo "" >&2
fi
