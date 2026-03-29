# modules/hostnamer.nix
{ lib, config, ... }:
let
  envHost = builtins.getEnv "PI_HOSTNAME";
  defaultHost = "rpi";
in
{
  options.deploy.hostName = lib.mkOption {
    type = lib.types.str;
    default = if envHost != "" then envHost else defaultHost;
    description = ''
      Hostname for this Pi. Provide via env var PI_HOSTNAME at build/switch time.
      Example:
        PI_HOSTNAME=rpi-worker1 nixos-rebuild switch --flake .#pi --impure
    '';
  };

  config = {
    networking.hostName = config.deploy.hostName;

    # Ensure a unique machine-id if image was cloned.
    systemd.services."first-boot-regenerate-machine-id" = {
      description = "Ensure unique machine-id on first boot";
      wantedBy = [ "multi-user.target" ];
      before = [ "network.target" ];
      serviceConfig = { Type = "oneshot"; };
      script = ''
        if [ ! -s /etc/machine-id ]; then
          ${config.systemd.package}/bin/systemd-machine-id-setup
        fi
      '';
    };
  };
}