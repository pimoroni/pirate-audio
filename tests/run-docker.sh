#!/bin/bash
# Run an install test locally in Docker. Needs an arm64 host or
# qemu-user-static, since the Raspberry Pi archive is arm64/armhf only.
#
#   ./tests/run-docker.sh [mopidy|clip-recorder]
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

case "${1:-mopidy}" in
mopidy)
	TEST=install-trixie.sh
	;;
clip-recorder)
	TEST=install-clip-recorder-trixie.sh
	;;
*)
	printf "Usage: %s [mopidy|clip-recorder]\n" "$0"
	exit 1
	;;
esac

exec docker run --rm \
	--platform linux/arm64 \
	-e TERM=xterm-256color \
	-v "$REPO_DIR:/src:ro" \
	debian:trixie-slim \
	bash "/src/tests/$TEST" /src
