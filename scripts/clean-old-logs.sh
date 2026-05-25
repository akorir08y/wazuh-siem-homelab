#!/bin/bash

# cleanup-old-logs.sh
# Deletes Wazuh alert and archive files older than 14 days.
# Recommended: run weekly via cron.

ALERTS_DIR="/var/ossec/logs/alerts/"
ARCHIVES_DIR="/var/ossec/logs/archives/"

find "$ALERTS_DIR" -type f -mtime +14 -exec rm -f {} \;
find "$ARCHIVES_DIR" -type f -mtime +14 -exec rm -f {} \;

echo "$(date): Cleaned up log files older than 14 days." >> /var/log/wazuh-cleanup.log