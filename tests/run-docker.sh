#!/bin/bash
# Run the Trixie install test locally in Docker. Needs an arm64 host or
# qemu-user-static, since the Raspberry Pi archive is arm64/armhf only.
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

exec docker run --rm \
	--platform linux/arm64 \
	-e TERM=xterm-256color \
	-v "$REPO_DIR:/src:ro" \
	debian:trixie-slim \
	bash /src/tests/install-trixie.sh /src
