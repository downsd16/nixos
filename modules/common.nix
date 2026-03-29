{ config, pkgs, lib, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  time.timeZone = "America/New_York";

  networking.useDHCP = lib.mkDefault true;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  users.users.devin = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 pydHk2lTg34l5kGRd6yXcjy+QcU8E8+Jfi4c9yVlCtY devin@desktop"
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    git
    vim
    curl
    htop
    jq
    docker-compose
  ];

  # Docker installation
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    daemon.settings = {
      "log-driver" = "journald";
      "iptables" = true;
      "ip-forward" = true;
    };
  };

  # Kernel sysctls often needed for container networking
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.bridge.bridge-nf-call-iptables" = 1;
    "net.bridge.bridge-nf-call-ip6tables" = 1;
  };
}