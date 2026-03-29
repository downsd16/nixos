# modules/rpi-auto-label.nix
{ lib, pkgs, config, ... }:

let
  cfg = config.rpi.autoLabel;
in
{
  options.rpi.autoLabel = {
    enable = lib.mkEnableOption "One-time labeling of boot/root partitions for Raspberry Pi";

    bootLabel = lib.mkOption {
      type = lib.types.str;
      default = "NIXOS_BOOT";
      description = "Filesystem label for /boot/firmware (vfat).";
    };

    rootLabel = lib.mkOption {
      type = lib.types.str;
      default = "NIXOS_ROOT";
      description = "Filesystem label for / (ext4).";
    };
  };

  config = lib.mkIf cfg.enable {
    # One-time service that labels the currently mounted partitions.
    systemd.services."rpi-label-partitions" = {
      description = "Label Raspberry Pi boot/root partitions (one-time)";
      wantedBy = [ "multi-user.target" ];
      after = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
      };
      script = ''
        set -euo pipefail

        MARKER="/var/lib/rpi-auto-label.done"
        if [ -f "$MARKER" ]; then
          echo "Labels already applied. Skipping."
          exit 0
        fi

        # Identify the currently mounted block devices
        ROOT_SRC="$(findmnt -n -o SOURCE /)"
        BOOT_SRC="$(findmnt -n -o SOURCE /boot/firmware || true)"

        echo "Root device: ${ROOT_SRC}"
        echo "Boot device: ${BOOT_SRC:-<none>}"

        # Label root (ext4)
        if [ -n "$ROOT_SRC" ]; then
          CUR_LABEL="$(${pkgs.e2fsprogs}/bin/e2label "$ROOT_SRC" || true)"
          if [ "$CUR_LABEL" != "${cfg.rootLabel}" ]; then
            echo "Setting root label to ${cfg.rootLabel}"
            ${pkgs.e2fsprogs}/bin/e2label "$ROOT_SRC" "${cfg.rootLabel}"
          else
            echo "Root already labeled ${cfg.rootLabel}"
          fi
        fi

        # Label boot (vfat), if present
        if [ -n "${BOOT_SRC:-}" ]; then
          echo "Setting boot label to ${cfg.bootLabel}"
          ${pkgs.dosfstools}/bin/fatlabel "$BOOT_SRC" "${cfg.bootLabel}" || true
        fi

        mkdir -p "$(dirname "$MARKER")"
        touch "$MARKER"
      '';
    };
  };
}