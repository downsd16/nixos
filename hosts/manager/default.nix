# hosts/manager/default.nix
{ lib, pkgs, config, ... }:
{
  imports = [
    ../../modules/common.nix
    #../../modules/docker-swarm-join.nix
    ./hardware.nix
  ];

  # Manager hostname
  networking.hostName = "manager";

  # Swarm ports (manager side)
  networking.firewall.allowedTCPPorts = [ 2377 7946 ];
  networking.firewall.allowedUDPPorts = [ 7946 4789 ];

  # Swarm manager auto-init (one-time)
  services.dockerSwarmBootstrap = {
    enable = true;
    role = "manager";
    initIfManager = true;
    openFirewall = true;
    # advertiseAddr = "10.0.0.10";
  };
}