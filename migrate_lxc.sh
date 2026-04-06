#!/bin/bash
# Proxmox Bulk LXC Migration Script (V5.0 - Industrial Edition)
# Author: LongPhan/gnolnos
# Features: Colorized UI, State-Aware, Smart Resize, Idempotency.

# --- Color Definitions ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# --- Header Art ---
echo -e "${CYAN}${BOLD}"
echo "=========================================================="
echo "      PROXMOX LXC BULK MIGRATOR - PRO V5.0         "
echo "=========================================================="
echo -e "${NC}"

# 1. Configuration & Prompts
echo -ne "${YELLOW}[?] Enter Target Storage name (e.g., thunderblade_ct, sg1tb): ${NC}"
read TARGET_STORAGE

if [ -z "$TARGET_STORAGE" ]; then 
    echo -e "${RED}❌ Error: Target storage cannot be empty!${NC}"
    exit 1
fi

echo -ne "${YELLOW}[?] Auto-restart running containers after move? (y/n): ${NC}"
read AUTO_RESTART

echo -e "${RED}${BOLD}"
echo "⚠️  WARNING: ALL SELECTED LXCS WILL BE MOVED TO [ $TARGET_STORAGE ]"
echo -ne "${YELLOW}Are you absolutely sure you want to proceed? (y/n): ${NC}"
read CONFIRM

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then 
    echo -e "${BLUE}🛑 Migration aborted by user. Stay safe!${NC}"
    exit 0
fi

echo -e "\n${CYAN}🚀 STARTING STATE-AWARE MIGRATION...${NC}"

# 2. Execution Loop
for ctid in $(pct list | awk 'NR>1 {print $1}'); do
    echo -e "${CYAN}----------------------------------------------------------${NC}"
    
    # Original Status
    ORIGINAL_STATUS=$(pct status $ctid | awk '{print $2}')
    
    # Idempotency Check
    CURRENT_STORAGE=$(pct config $ctid | grep '^rootfs:' | awk '{print $2}' | cut -d':' -f1)
    if [ "$CURRENT_STORAGE" == "$TARGET_STORAGE" ]; then
        echo -e "${BLUE}⏭️  LXC $ctid: Already on [ $TARGET_STORAGE ]. Skipping.${NC}"
        continue
    fi

    # Handle running containers
    SHOULD_RESTART="false"
    if [ "$ORIGINAL_STATUS" == "running" ]; then
        if [[ "$AUTO_RESTART" == "y" || "$AUTO_RESTART" == "Y" ]]; then
            echo -e "${BLUE}⏳ LXC $ctid is running. Stopping...${NC}"
            pct stop $ctid
            SHOULD_RESTART="true"
        else
            echo -e "${YELLOW}⏳ Skipping LXC $ctid: Running (Auto-restart disabled).${NC}"
            continue
        fi
    fi

    # Migration Loop
    while true; do
        echo -e "${CYAN}[+] Moving LXC $ctid: [ $CURRENT_STORAGE ] -> [ $TARGET_STORAGE ]...${NC}"
        
        pct move_volume $ctid rootfs $TARGET_STORAGE --delete 1
        EXIT_CODE=$?

        if [ $EXIT_CODE -eq 0 ]; then
            echo -e "${GREEN}✅ Success: LXC $ctid moved to $TARGET_STORAGE.${NC}"
            
            if [ "$SHOULD_RESTART" == "true" ]; then
                echo -e "${CYAN}⚡ Restoring state: Starting LXC $ctid...${NC}"
                pct start $ctid
            fi
            break
        fi

        # Failure Handling
        echo -e "${RED}❌ Error: Migration failed for LXC $ctid (Code: $EXIT_CODE).${NC}"
        echo -e "${YELLOW}💡 Possible cause: Disk Full (RAW conversion overhead).${NC}"
        echo -ne "${BOLD}${YELLOW}👉 Add space and retry? (Enter GB, e.g. '2', or 'n' to skip): ${NC}"
        read RESIZE_INPUT

        if [[ "$RESIZE_INPUT" =~ ^[0-9]+$ ]]; then
            echo -e "${CYAN}🔧 Resizing RootFS of $ctid by +${RESIZE_INPUT}G...${NC}"
            pct resize $ctid rootfs +${RESIZE_INPUT}G
            echo -e "${BLUE}🔄 Retrying migration...${NC}"
        else
            echo -e "${YELLOW}⏭️  Skipping LXC $ctid as requested.${NC}"
            break
        fi
    done
done

echo -e "${CYAN}==========================================================${NC}"
echo -e "${GREEN}${BOLD}🎉 MISSION ACCOMPLISHED! ALL SYSTEMS ARE GO.${NC}"
echo -e "${CYAN}==========================================================${NC}"
