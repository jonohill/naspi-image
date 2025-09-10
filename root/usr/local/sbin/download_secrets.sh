#!/bin/bash

set -euo pipefail

REPO="$NASPI_REPO"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

git clone --depth 1 --no-checkout "$REPO" "$tmp_dir"
cd "$tmp_dir"
git sparse-checkout init --cone
git sparse-checkout set secrets/
git checkout

HOST_KEY_PATH="/etc/ssh/ssh_host_ed25519_key"

# Decrypt/copy over to /run
cd secrets
find . -mindepth 1 -print0 | while IFS= read -r -d $'\0' item; do
    if [ -d "$item" ]; then
        mkdir -p "/run/$item"
    elif [ -f "$item" ]; then
        filename="$(basename "$item")"
        if [[ "$filename" != *.enc ]]; then
            continue
        fi
        # Remove .enc extension from the output path
        output_item="${item%.enc}"
        age \
            --decrypt \
            --identity "$HOST_KEY_PATH" \
            --output "/run/$output_item" \
            "$item"
        chmod 600 "/run/$output_item"
    fi
done
