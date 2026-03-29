{ config, pkgs, lib, ... }:

let
  cfg = config.services.dockerSwarmBootstrap;
in
{
  options.services.dockerSwarmBootstrap = {
    enable = lib.mkEnableOption "Bootstrap Docker Swarm (init manager, join workers)";

    role = lib.mkOption {
      type = lib.types.enum [ "manager" "worker" ];
      default = "worker";
      description = "Whether this node should init the swarm (manager) or join it (worker).";
    };

    managerAddr = lib.mkOption {
      type = lib.types.str;
      default = "10.0.0.10:2377";
      description = "Manager address:port used by workers to join the swarm.";
    };

    tokenPath = lib.mkOption {
      type = lib.types.str;
      default = "/etc/docker-swarm/worker-token";
      description = "Path to worker join token file on workers (root-readable).";
    };

    advertiseAddr = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional advertise address passed to swarm init/join (e.g. node LAN IP).";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open Swarm-related firewall ports (2377/tcp, 7946/tcp+udp, 4789/udp).";
    };

    # Optional: if you want the manager to also advertise a specific address for init
    initListenAddr = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional listen address for swarm init (rarely needed).";
    };
  };

  config = lib.mkIf cfg.enable {

    # Create directory for token file; we do NOT write secrets from Nix.
    systemd.tmpfiles.rules = [
      "d /etc/docker-swarm 0750 root root -"
    ];

    # Firewall ports commonly required for Docker Swarm operation
    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ 2377 7946 ];
      allowedUDPPorts = [ 7946 4789 ];
    };

    systemd.services.docker-swarm-bootstrap = {
      description = "Bootstrap Docker Swarm (init on manager, join on workers)";
      wants = [ "network-online.target" "docker.service" ];
      after  = [ "network-online.target" "docker.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # Helps avoid leaking token in journald if something echoes it (we don't echo it anyway)
        StandardOutput = "journal";
        StandardError  = "journal";
      };

      script = ''
        set -euo pipefail

        DOCKER="${pkgs.docker}/bin/docker"
        GREP="${pkgs.gnugrep}/bin/grep"

        # If already part of a swarm, nothing to do.
        if $DOCKER info 2>/dev/null | $GREP -q "Swarm: active"; then
          echo "Already in swarm; skipping bootstrap."
          exit 0
        fi

        EXTRA_ADVERTISE=""
        ${lib.optionalString (cfg.advertiseAddr != null) ''
          EXTRA_ADVERTISE="--advertise-addr ${cfg.advertiseAddr}"
        ''}

        if [ "${cfg.role}" = "manager" ]; then
          EXTRA_LISTEN=""
          ${lib.optionalString (cfg.initListenAddr != null) ''
            EXTRA_LISTEN="--listen-addr ${cfg.initListenAddr}"
          ''}

          echo "Initializing Docker Swarm (manager)..."
          # No token involved on manager init
          $DOCKER swarm init $EXTRA_ADVERTISE $EXTRA_LISTEN || true

          # Note: `|| true` avoids failing boot if already initialized but docker info didn't reflect it yet.
          exit 0
        fi

        # Worker join path
        if [ ! -r "${cfg.tokenPath}" ]; then
          echo "Worker token file not found/readable at ${cfg.tokenPath}; not joining swarm."
          echo "Copy token to this node and then run: systemctl start docker-swarm-bootstrap"
          exit 0
        fi

        TOKEN="$(tr -d '\n' < "${cfg.tokenPath}")"

        echo "Joining Docker Swarm at ${cfg.managerAddr}..."
        $DOCKER swarm join $EXTRA_ADVERTISE --token "$TOKEN" "${cfg.managerAddr}"
      '';
    };
  };
}