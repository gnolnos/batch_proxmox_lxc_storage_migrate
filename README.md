# Proxmox Bulk LXC Migrator 🚀

A simple, interactive bash script to safely bulk migrate all LXC containers to a new storage pool in Proxmox VE. 

Perfect for scenarios where you need to replace SSDs, rebuild ZFS pools, or perform live storage migrations without clicking through the GUI dozens of times.

## ✨ Features
- **Interactive Prompt:** Asks for the target storage name.
- **Failsafe Confirmation:** Prevents accidental executions.
- **Safety First:** Automatically skips `running` containers to prevent data corruption.
- **Auto-Cleanup:** Deletes the old volume after a successful move.

## 🛠️ Usage


   ```bash
   # Run the script on your Proxmox node shell:
   bash -c "$(curl -fsSL https://raw.githubusercontent.com/gnolnos/batch_proxmox_lxc_storage_migrate/main/migrate_lxc.sh)"
   ```
⚠️ **Tip:** 
It's good practice to inspect the script at the URL before executing it.

⚠️ **Disclaimer:**
Use at your own risk. Always make sure you have working backups (e.g., via Proxmox Backup Server) before performing bulk storage operations.
