#!/bin/bash

set -euo pipefail

REPO="${NASPI_REPO}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

git clone --depth 1 --no-checkout "$REPO" "$tmp_dir"
cd "$tmp_dir"
git sparse-checkout init --cone
git sparse-checkout set "secrets/*"
git checkout

HOST_KEY_PATH="/root/.ssh/host_key"

# Decrypt/copy over to /run
cd secrets
find . -mindepth 1 -print0 | while IFS= read -r -d $'\0' item; do
    if [[ "$item" == .git* ]]; then
        continue
    fi

    if [ -d "$item" ]; then
        mkdir -p "/run/$item"
    elif [ -f "$item" ]; then
        age \
            --decrypt \
            --identity "$HOST_KEY_PATH" \
            --output "/run/$item" \
            "$item"
        chmod 600 "/run/$item"
    fi
done
