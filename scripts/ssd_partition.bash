#!/usr/bin/env bash
set -euo pipefail

# === Configuration ===
DISK="/dev/sda"                    # change to your SSD device
EFI_SIZE="512MiB"
EFI_PART="${DISK}1"
ROOT_PART="${DISK}2"
ROOT_LABEL="nixos"
MOUNT_POINT="/mnt"
SWAPFILE_SIZE_GB=2                 # swapfile size in GB (set 0 to skip)

# === Safety check ===
if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root." >&2
  exit 1
fi

read -p "WARNING: This will erase ${DISK}. Type YES to continue: " CONFIRM
if [ "$CONFIRM" != "YES" ]; then
  echo "Aborted."
  exit 1
fi

# Unmount targets if mounted
umount "${MOUNT_POINT}"/* 2>/dev/null || true
umount "${MOUNT_POINT}" 2>/dev/null || true

# Wipe partition table
sgdisk --zap-all "$DISK"
wipefs -a "$DISK"

# Create GPT and partitions
parted --script "$DISK" mklabel gpt
parted --script "$DISK" mkpart primary fat32 1MiB ${EFI_SIZE}
parted --script "$DISK" set 1 boot on
parted --script "$DISK" mkpart primary ext4 ${EFI_SIZE} 100%

# Give kernel time to refresh
sleep 1
partprobe "$DISK"

# Format partitions
mkfs.vfat -F32 -n EFI "$EFI_PART"
mkfs.ext4 -L "$ROOT_LABEL" "$ROOT_PART"

# Mount root and EFI
mkdir -p "$MOUNT_POINT"
mount "$ROOT_PART" "$MOUNT_POINT"
mkdir -p "$MOUNT_POINT/boot"
mount "$EFI_PART" "$MOUNT_POINT/boot"

# Create swapfile if requested
if [ "$SWAPFILE_SIZE_GB" -gt 0 ]; then
  SWAPFILE="$MOUNT_POINT/swapfile"
  fallocate -l "${SWAPFILE_SIZE_GB}G" "$SWAPFILE" || dd if=/dev/zero of="$SWAPFILE" bs=1M count=$((SWAPFILE_SIZE_GB*1024))
  chmod 600 "$SWAPFILE"
  mkswap "$SWAPFILE"
  swapon "$SWAPFILE"
  echo "Created and enabled swapfile at $SWAPFILE (${SWAPFILE_SIZE_GB}G)"
fi

# Summary
echo "Partitioning and formatting complete."
echo "Root mounted at $MOUNT_POINT (label: $ROOT_LABEL)"
echo "EFI mounted at $MOUNT_POINT/boot"
if [ "$SWAPFILE_SIZE_GB" -gt 0 ]; then
  echo "Swapfile placed at $SWAPFILE"
fi

echo "Next: proceed with NixOS install using --root $MOUNT_POINT and your flake."