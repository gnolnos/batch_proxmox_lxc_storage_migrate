#!/bin/bash
# Proxmox Bulk LXC Migration Script (Interactive)
# Author: gnolnos (Long Phan)
# Description: Safely bulk move all stopped LXC containers to a new storage pool.

# 1. Prompt for Target Storage
read -p "Enter Target Storage name (e.g., local-zfs, pbs-store): " TARGET_STORAGE

# Validate input
if [ -z "$TARGET_STORAGE" ]; then
    echo "❌ Error: Target storage cannot be empty!"
    exit 1
fi

# 2. Safety Confirmation
echo "⚠️ WARNING: All stopped LXCs will be moved to [ $TARGET_STORAGE ] and deleted from their original storage."
read -p "Are you sure you want to proceed? (y/n): " CONFIRM

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "🛑 Migration aborted. Stay safe!"
    exit 0
fi

# 3. Execute Migration
echo "🚀 STARTING BULK MIGRATION TO: $TARGET_STORAGE"
for ctid in $(pct list | awk 'NR>1 {print $1}'); do
    # Skip running containers to prevent data corruption
    STATUS=$(pct status $ctid | awk '{print $2}')
    if [ "$STATUS" == "running" ]; then
        echo "⏳ Skipping LXC $ctid because it is currently running..."
        continue
    fi

    echo "=========================================="
    echo "[+] Moving RootFS of LXC $ctid to $TARGET_STORAGE..."
    pct move_volume $ctid rootfs $TARGET_STORAGE --delete 1
done

echo "=========================================="
echo "✅ BULK MIGRATION COMPLETED!"
