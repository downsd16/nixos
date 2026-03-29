# hosts/manager/default.nix
{ lib, pkgs, config, ... }:
{
  imports = [
    ../../modules/common.nix
    ../../modules/docker-swarm-join.nix
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

  # Nice-to-have for remote access
  # services.avahi.enable = true;
  # services.avahi.nssmdns4 = true;

  # If using the Swarm-based Guacamole module we built earlier:
  #services.guacamoleSwarm = {
  #  enable = true;
  #  webPort = 8080;
  #  managerConstraint = "node.labels.role == manager";
  #  workerConstraint  = "node.labels.role == worker";
  #  guacdReplicas = 1;
  #  dbPasswordFile = "/etc/guacamole/db-password";
  };
}
