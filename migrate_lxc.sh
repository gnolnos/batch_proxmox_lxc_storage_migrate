#!/bin/bash
# Proxmox Bulk LXC Migration Script (V4.0 - State-Aware & Smart Resize)
# Author: [Long Phan/gnolnos]
# Description: Bulk move LXCs with auto-stop/restart capability and idempotency check.

# 1. Configuration & Prompts
read -p "Enter Target Storage name (e.g., local-zfs, sg1tb): " TARGET_STORAGE
if [ -z "$TARGET_STORAGE" ]; then echo "❌ Error: Empty storage!"; exit 1; fi

read -p "If a container is running, should I stop, move, and RESTART it? (y/n): " AUTO_RESTART
read -p "Are you sure you want to proceed? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then echo "🛑 Aborted."; exit 0; fi

echo "🚀 STARTING STATE-AWARE MIGRATION TO: $TARGET_STORAGE"

# 2. Execution Loop
for ctid in $(pct list | awk 'NR>1 {print $1}'); do
    echo "=========================================="
    
    # Capture original status
    ORIGINAL_STATUS=$(pct status $ctid | awk '{print $2}')
    
    # Idempotency Check (Is it already there?)
    CURRENT_STORAGE=$(pct config $ctid | grep '^rootfs:' | awk '{print $2}' | cut -d':' -f1)
    if [ "$CURRENT_STORAGE" == "$TARGET_STORAGE" ]; then
        echo "⏭️ Skipping LXC $ctid: Already on [ $TARGET_STORAGE ]."
        continue
    fi

    # Handle running containers
    SHOULD_RESTART="false"
    if [ "$ORIGINAL_STATUS" == "running" ]; then
        if [[ "$AUTO_RESTART" == "y" || "$AUTO_RESTART" == "Y" ]]; then
            echo "⏳ LXC $ctid is running. Stopping for migration..."
            pct stop $ctid
            SHOULD_RESTART="true"
        else
            echo "⏳ Skipping LXC $ctid: It is currently running (Auto-restart disabled)."
            continue
        fi
    fi

    # Migration with Smart Resize
    while true; do
        echo "[+] Moving RootFS of LXC $ctid from [ $CURRENT_STORAGE ] to [ $TARGET_STORAGE ]..."
        pct move_volume $ctid rootfs $TARGET_STORAGE --delete 1
        EXIT_CODE=$?

        if [ $EXIT_CODE -eq 0 ]; then
            echo "✅ LXC $ctid moved successfully."
            
            # THE BOOM MOMENT: Restore original state
            if [ "$SHOULD_RESTART" == "true" ]; then
                echo "⚡ Restoring state: Starting LXC $ctid..."
                pct start $ctid
            fi
            break
        fi

        # Failure Handling (No space left etc.)
        echo "❌ Error moving LXC $ctid (Code: $EXIT_CODE)."
        read -p "Add space and retry? (Enter GB, e.g. '2', or 'n' to skip): " RESIZE_INPUT
        if [[ "$RESIZE_INPUT" =~ ^[0-9]+$ ]]; then
            pct resize $ctid rootfs +${RESIZE_INPUT}G
            echo "🔄 Retrying..."
        else
            echo "⏭️ Skipping LXC $ctid."
            break
        fi
    done
done

echo "=========================================="
echo "🎉 ALL DONE! EVERYTHING IS BACK TO NORMAL!"
