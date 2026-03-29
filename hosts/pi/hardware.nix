{ config, lib, pkgs, ... }:

{
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  # Typical Pi firmware mount point
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_ROOT";
    fsType = "ext4";
  };

  fileSystems."/boot/firmware" = {
    device = "/dev/disk/by-label/NIXOS_BOOT";
    fsType = "vfat";
  };

  boot.initrd.availableKernelModules = [
    "xhci_pci" "usbhid" "usb_storage" "sd_mod"
  ];

  swapDevices = [];
}