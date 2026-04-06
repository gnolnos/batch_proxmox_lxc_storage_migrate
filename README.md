# Proxmox Bulk LXC Migrator 🚀

A simple, interactive bash script to safely bulk migrate all LXC containers to a new storage pool in Proxmox VE. 

Perfect for scenarios where you need to replace SSDs, rebuild ZFS pools, or perform live storage migrations without clicking through the GUI dozens of times.

## ✨ Features
- **Interactive Prompt:** Asks for the target storage name.
- **Failsafe Confirmation:** Prevents accidental executions.
- **Safety First:** Automatically skips `running` containers to prevent data corruption.
- **Auto-Cleanup:** Deletes the old volume after a successful move.

## 🛠️ Usage

1. Download the script to your Proxmox node:
   ```bash
   wget https://raw.githubusercontent.com/gnolnos/batch_proxmox_lxc_storage_migrate/main/migrate_lxc.sh
   
2. Make it executable:
   ```bash
   chmod +x migrate_lxc.sh

3. Stop the containers you want to move:
   ```bash
   # Tip: Stop all running LXCs at once
   for i in $(pct list | awk '/running/ {print $1}'); do pct stop $i; done

4. Run the script:
   ```bash
   ./migrate_lxc.sh
⚠️ Disclaimer
Use at your own risk. Always make sure you have working backups (e.g., via Proxmox Backup Server) before performing bulk storage operations.
