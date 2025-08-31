#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat << EOF
Usage: $0 [OPTION]
Encrypt, decrypt, or rotate secrets in the secrets directory.

Options:
    -e, --encrypt   Encrypt all plain files in the secrets directory
    -d, --decrypt   Decrypt all encrypted files in the secrets directory
    -r, --rotate    Rotate secrets (decrypt then encrypt with current key)
    -h, --help      Show this help message

Environment Variables:
    AGE_KEY         Required. The age private key for encryption/decryption.

Files:
    host.pub        Required. Public key file used for encryption (allows host to decrypt).

EOF
}

OPERATION=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--encrypt)
            OPERATION="encrypt"
            shift
            ;;
        -d|--decrypt)
            OPERATION="decrypt"
            shift
            ;;
        -r|--rotate)
            OPERATION="rotate"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option '$1'"
            usage
            exit 1
            ;;
    esac
done

if [[ -z "$OPERATION" ]]; then
    echo "Error: No operation specified. Use -e, -d, or -r."
    usage
    exit 1
fi

if [[ -z "$AGE_KEY" ]]; then
    echo "Error: AGE_KEY environment variable is not set."
    exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

AGE_KEY_FILE="$tmpdir/age.key"
echo "$AGE_KEY" > "$tmpdir/age.key"

HOST_PUBKEY_FILE="host.pub"

encrypt() {
    file="$1"

    pubkey="$(age-keygen -y "$AGE_KEY_FILE")"
    age -e \
        -a \
        -o "$file.enc" \
        -r "$pubkey" \
        -R "$HOST_PUBKEY_FILE" \
        "$file"
}

decrypt() {
    file="$1"
    if [[ "$file" != *.enc ]]; then
        echo "Error: Encrypted file '$file' does not end with .enc."
        exit 1
    fi
    if [[ ! -f "$file" ]]; then
        echo "Error: '$file' is not a regular file."
        exit 1
    fi
    plain_file="${file%.enc}"

    age -d \
        -o "$plain_file" \
        -i "$AGE_KEY_FILE" \
        "$file"

    rm -f "$file"
}

rotate() {
    file="$1"
    if [[ "$file" != *.enc ]]; then
        echo "Error: Encrypted file '$file' does not end with .enc."
        exit 1
    fi
    plain_file="${file%.enc}"

    decrypt "$file"
    encrypt "$plain_file"
}

find secrets -mindepth 1 -print0 | while IFS= read -r -d $'\0' item; do
    if [[ "$item" == *.gitignore ]] || [[ "$item" == *.md ]]; then
        continue
    fi
    if [ -d "$item" ]; then
        continue
    fi

    case "$OPERATION" in
        "decrypt")
            if [[ "$item" == *.enc ]]; then
                decrypt "$item"
            fi
            ;;
        "encrypt")
            if [[ "$item" != *.enc ]]; then
                encrypt "$item"
            fi
            ;;
        "rotate")
            if [[ "$item" == *.enc ]]; then
                rotate "$item"
            fi
            ;;
    esac
done
