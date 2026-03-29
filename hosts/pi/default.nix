# hosts/pi/default.nix
{ lib, pkgs, config, ... }:
{
  imports = [
    ../../modules/common.nix
    ../../modules/docker-swarm-join.nix
    ../../modules/hostnamer.nix
    ../../modules/rpi-auto-label.nix
    ./hardware.nix
  ];

  rpi.autoLabel.enable = true;
  rpi.autoLabel.bootLabel = "NIXOS_BOOT";
  rpi.autoLabel.rootLabel = "NIXOS_ROOT";

  # Firewall ports used by Swarm
  networking.firewall.allowedTCPPorts = [ 2377 7946 ];
  networking.firewall.allowedUDPPorts = [ 7946 4789 ];

  # Swarm bootstrap: You can toggle role by hostname after boot
  services.dockerSwarmBootstrap = {
    enable = true;
    role = "worker";
    managerAddr = "10.0.0.10:2377";
    tokenPath = "/etc/docker-swarm/worker-token";
    openFirewall = true;
  };

  # Disable xserver for headless
  services.xserver.enable = false;
}