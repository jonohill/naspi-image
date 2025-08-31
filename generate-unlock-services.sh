#!/bin/bash

# Script to generate unlock-all-disks.service based on disks.txt
# This should be run at build time to bake the disk list into the bootc image

set -e

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
DISKS_FILE="$SCRIPT_DIR/disks.txt"
SERVICE_FILE="$SCRIPT_DIR/root/etc/systemd/system/unlock-all-disks.service"

if [ ! -f "$DISKS_FILE" ]; then
    echo "Error: $DISKS_FILE not found" >&2
    exit 1
fi

echo "Generating unlock-all-disks.service from $DISKS_FILE..." >&2

# Read disks and create service instances
WANTS_LIST=""
AFTER_LIST=""

while IFS= read -r disk_id || [ -n "$disk_id" ]; do
    # Skip empty lines and comments
    disk_id=$(echo "$disk_id" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [ -z "$disk_id" ] || [ "${disk_id:0:1}" = "#" ]; then
        continue
    fi

    # Escape the UUID for systemd service names
    # systemd-escape is the proper way to escape identifiers for systemd
    escaped_disk_id=$(systemd-escape "$disk_id")

    # Add to the lists
    if [ -z "$WANTS_LIST" ]; then
        WANTS_LIST="unlock-data-disk@${escaped_disk_id}.service"
        AFTER_LIST="unlock-data-disk@${escaped_disk_id}.service"
    else
        WANTS_LIST="$WANTS_LIST unlock-data-disk@${escaped_disk_id}.service"
        AFTER_LIST="$AFTER_LIST unlock-data-disk@${escaped_disk_id}.service"
    fi

    echo "  Adding disk: $disk_id (escaped: $escaped_disk_id)" >&2
done < "$DISKS_FILE"

if [ -z "$WANTS_LIST" ]; then
    echo "Warning: No disk IDs found in $DISKS_FILE" >&2
    WANTS_LIST="# No disks configured"
    AFTER_LIST="# No disks configured"
fi

# Generate the service file
cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Unlock All Encrypted Data Disks
Wants=$WANTS_LIST
After=$AFTER_LIST

[Install]
WantedBy=multi-user.target
EOF

echo "Generated $SERVICE_FILE with $(echo "$WANTS_LIST" | wc -w) disk services" >&2
echo "Service file content:" >&2
echo "====================" >&2
cat "$SERVICE_FILE"
