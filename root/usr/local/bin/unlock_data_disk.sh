#!/usr/bin/env bash

set -euo pipefail

DEVICE="$1"
MAPPER_NAME="$2"

if [ -z "$DEVICE" ] || [ -z "$MAPPER_NAME" ]; then
  echo "Usage: $0 <device> <mapper_name>"
  exit 1
fi

# List devices
blkid -t TYPE=crypto_LUKS -o device 2>/dev/null

cryptsetup luksOpen "$LUKS_DEVICE" "$MAPPER_NAME"
