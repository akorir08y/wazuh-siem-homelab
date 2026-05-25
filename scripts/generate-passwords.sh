#!/bin/bash
# generate-passwords.sh
# Extracts the generated passwords from the Wazuh installation tarball
# and saves them to a secure file (recommend moving to a password manager).

set -e

TARBALL="wazuh-install-files.tar"
OUTPUT_FILE="wazuh-passwords.txt"

if [ ! -f "$TARBALL" ]; then
    echo "Error: $TARBALL not found in current directory."
    echo "Run this script from the directory where Wazuh was installed (e.g., /opt/Wazuh)."
    exit 1
fi

echo "Extracting passwords from $TARBALL ..."
sudo tar -O -xvf "$TARBALL" wazuh-install-files/wazuh-passwords.txt > "$OUTPUT_FILE"

echo "Passwords saved to $OUTPUT_FILE"
echo "IMPORTANT: Move this file to a safe location (e.g., password manager) and delete it from the server."