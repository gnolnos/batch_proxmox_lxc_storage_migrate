#!/bin/bash
# Proxmox Bulk LXC Migration Script (Interactive & Smart Resize)
# Author: gnolnos (Long Phan)
# Description: Safely bulk move LXC containers. Auto-skips running CTs and CTs already on target. Auto-prompts for resize on failure.

# 1. Prompt for Target Storage
read -p "Enter Target Storage name (e.g., local-zfs, skyhawk): " TARGET_STORAGE

if [ -z "$TARGET_STORAGE" ]; then
    echo "❌ Error: Target storage cannot be empty!"
    exit 1
fi

# 2. Safety Confirmation
echo "⚠️ WARNING: All stopped LXCs will be moved to [ $TARGET_STORAGE ]."
read -p "Are you sure you want to proceed? (y/n): " CONFIRM

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "🛑 Migration aborted. Stay safe!"
    exit 0
fi

# 3. Execute Migration
echo "🚀 STARTING BULK MIGRATION TO: $TARGET_STORAGE"
for ctid in $(pct list | awk 'NR>1 {print $1}'); do
    echo "=========================================="
    
    # Ktra trạng thái chạy
    STATUS=$(pct status $ctid | awk '{print $2}')
    if [ "$STATUS" == "running" ]; then
        echo "⏳ Skipping LXC $ctid: Currently running."
        continue
    fi

    # Ktra vị trí ổ cứng hiện tại (Idempotency Check)
    # Lệnh này sẽ bóc tách dòng rootfs: local_zfs:subvol-xxx để lấy ra chữ 'local_zfs'
    CURRENT_STORAGE=$(pct config $ctid | grep '^rootfs:' | awk '{print $2}' | cut -d':' -f1)
    
    if [ "$CURRENT_STORAGE" == "$TARGET_STORAGE" ]; then
        echo "⏭️ Skipping LXC $ctid: Already on [ $TARGET_STORAGE ]."
        continue
    fi

    # Bắt đầu vòng lặp chuyển nhà và xử lý lỗi
    while true; do
        echo "[+] Moving RootFS of LXC $ctid from [ $CURRENT_STORAGE ] to [ $TARGET_STORAGE ]..."
        
        pct move_volume $ctid rootfs $TARGET_STORAGE --delete 1
        EXIT_CODE=$?

        if [ $EXIT_CODE -eq 0 ]; then
            echo "✅ LXC $ctid moved successfully."
            break
        fi

        echo "❌ Error: Failed to move LXC $ctid (Exit code: $EXIT_CODE)."
        echo "💡 Hint: Usually caused by 'No space left' on target device."
        
        read -p "Do you want to add space and retry? (Enter GB to add, e.g., '2', or 'n' to skip): " RESIZE_INPUT

        if [[ "$RESIZE_INPUT" =~ ^[0-9]+$ ]]; then
            echo "🔧 Resizing LXC $ctid by +${RESIZE_INPUT}G..."
            pct resize $ctid rootfs +${RESIZE_INPUT}G
            echo "🔄 Retrying migration for LXC $ctid..."
        else
            echo "⏭️ Skipping LXC $ctid and moving to the next one..."
            break
        fi
    done

done

echo "=========================================="
echo "🎉 BULK MIGRATION COMPLETED!"
