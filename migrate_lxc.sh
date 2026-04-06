#!/bin/bash
# Proxmox Bulk LXC Migration Script (Interactive & Smart Resize)
# Author: gnolnos (Long Phan)
# Description: Safely bulk move LXC containers with auto-resize prompt on failure.

# 1. Prompt for Target Storage
read -p "Enter Target Storage name (e.g., local-zfs, skyhawk): " TARGET_STORAGE

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
    # Skip running containers
    STATUS=$(pct status $ctid | awk '{print $2}')
    if [ "$STATUS" == "running" ]; then
        echo "⏳ Skipping LXC $ctid because it is currently running..."
        continue
    fi

    echo "=========================================="
    
    # Vòng lặp vô hạn (chỉ thoát khi thành công hoặc người dùng chọn Skip)
    while true; do
        echo "[+] Moving RootFS of LXC $ctid to $TARGET_STORAGE..."
        
        # Chạy lệnh move và bắt lại Exit Code
        pct move_volume $ctid rootfs $TARGET_STORAGE --delete 1
        EXIT_CODE=$?

        # Nếu thành công (Exit Code = 0)
        if [ $EXIT_CODE -eq 0 ]; then
            echo "✅ LXC $ctid moved successfully."
            break # Thoát vòng lặp while, đi tới LXC tiếp theo
        fi

        # Nếu thất bại (Exit Code != 0)
        echo "❌ Error: Failed to move LXC $ctid (Exit code: $EXIT_CODE)."
        echo "💡 Hint: This is often caused by 'No space left' when converting ZFS to ext4/raw."
        
        # Hỏi ý kiến người dùng
        read -p "Do you want to add space and retry? (Enter GB to add, e.g., '2', or 'n' to skip): " RESIZE_INPUT

        # Kiểm tra xem người dùng có gõ số hợp lệ không (Dùng Regular Expression)
        if [[ "$RESIZE_INPUT" =~ ^[0-9]+$ ]]; then
            echo "🔧 Resizing LXC $ctid by +${RESIZE_INPUT}G..."
            pct resize $ctid rootfs +${RESIZE_INPUT}G
            
            # Sau khi resize, vòng lặp while sẽ tự động quay lại đầu và chạy move_volume lần nữa
            echo "🔄 Retrying migration for LXC $ctid..."
        else
            echo "⏭️ Skipping LXC $ctid and moving to the next one..."
            break # Thoát vòng lặp while để đi tới LXC tiếp theo
        fi
    done

done

echo "=========================================="
echo "🎉 BULK MIGRATION COMPLETED!"
