{ config, pkgs, lib, ... }:

let
  cfg = config.services.guacamoleSwarm;
  stackName = cfg.stackName;
  stackFile = "/etc/${stackName}/stack.yml";
  initSql   = "/etc/${stackName}/initdb.sql";
  secretName = "${stackName}_db_password";
in
{
  options.services.guacamoleSwarm = {
    enable = lib.mkEnableOption "Deploy Apache Guacamole on Docker Swarm (manager runs guacamole+mariadb, workers run guacd)";

    stackName = lib.mkOption {
      type = lib.types.str;
      default = "guac";
      description = "Docker stack name.";
    };

    managerConstraint = lib.mkOption {
      type = lib.types.str;
      default = "node.labels.role == manager";
      description = "Swarm placement constraint for manager-only services.";
    };

    workerConstraint = lib.mkOption {
      type = lib.types.str;
      default = "node.labels.role == worker";
      description = "Swarm placement constraint for worker-only services (Pis).";
    };

    guacdReplicas = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = "How many guacd replicas to run across worker nodes.";
    };

    webPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Host port for Guacamole web (HTTP).";
    };

    mariadbImage = lib.mkOption {
      type = lib.types.str;
      default = "mariadb:11";
      description = "MariaDB image tag.";
    };

    guacamoleImage = lib.mkOption {
      type = lib.types.str;
      default = "guacamole/guacamole:1.5.5";
      description = "Guacamole webapp image tag.";
    };

    guacdImage = lib.mkOption {
      type = lib.types.str;
      default = "guacamole/guacd:1.5.5";
      description = "guacd image tag.";
    };

    dbName = lib.mkOption {
      type = lib.types.str;
      default = "guacamole_db";
      description = "Database name.";
    };

    dbUser = lib.mkOption {
      type = lib.types.str;
      default = "guac";
      description = "Database user.";
    };

    # IMPORTANT: this file must exist on the manager at runtime and NOT be in the Nix store.
    dbPasswordFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/guacamole/db-password";
      description = "Path to a local file containing the DB password (used to create a Swarm secret).";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open the Guacamole web port on the manager firewall.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Ensure docker is enabled (you likely already do this elsewhere)
    virtualisation.docker.enable = true;

    # Create directories for stack artifacts
    systemd.tmpfiles.rules = [
      "d /etc/${stackName} 0750 root root -"
      "d /etc/guacamole 0750 root root -"
    ];

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.webPort ];
    };

    # Ship the stack YAML (no secrets in here)
    environment.etc."${stackName}/stack.yml".text = ''
      version: "3.8"

      networks:
        guacnet:
          driver: overlay
          attachable: true

      volumes:
        mariadb_data:

      secrets:
        db_password:
          external: true
          name: ${secretName}

      services:
        mariadb:
          image: ${cfg.mariadbImage}
          networks: [ "guacnet" ]
          volumes:
            - mariadb_data:/var/lib/mysql
            - ${initSql}:/docker-entrypoint-initdb.d/initdb.sql:ro
          environment:
            MYSQL_DATABASE: "${cfg.dbName}"
            MYSQL_USER: "${cfg.dbUser}"
            # Use Swarm secret for password
            MYSQL_PASSWORD_FILE: "/run/secrets/db_password"
            MYSQL_ROOT_PASSWORD_FILE: "/run/secrets/db_password"
          secrets:
            - db_password
          deploy:
            placement:
              constraints:
                - ${cfg.managerConstraint}

        guacd:
          image: ${cfg.guacdImage}
          networks: [ "guacnet" ]
          deploy:
            mode: replicated
            replicas: ${toString cfg.guacdReplicas}
            placement:
              constraints:
                - ${cfg.workerConstraint}

        guacamole:
          image: ${cfg.guacamoleImage}
          networks: [ "guacnet" ]
          ports:
            - "${toString cfg.webPort}:8080"
          environment:
            GUACD_HOSTNAME: "guacd"
            GUACD_PORT: "4822"
            MYSQL_HOSTNAME: "mariadb"
            MYSQL_PORT: "3306"
            MYSQL_DATABASE: "${cfg.dbName}"
            MYSQL_USER: "${cfg.dbUser}"
            MYSQL_PASSWORD_FILE: "/run/secrets/db_password"
          secrets:
            - db_password
          deploy:
            placement:
              constraints:
                - ${cfg.managerConstraint}
    '';

    # 1) Generate initdb.sql once (used by MariaDB's entrypoint on first start)
    # 2) Create/update swarm secret from cfg.dbPasswordFile
    # 3) Deploy stack
    systemd.services."${stackName}-deploy" = {
      description = "Deploy ${stackName} (Guacamole) Docker Swarm stack";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" "docker.service" ];
      after = [ "network-online.target" "docker.service" ];

      # If you already have docker-swarm-bootstrap.service, also order after it:
      # (If it doesn't exist, systemd just ignores it.)
      after = [ "${stackName}-initdb.service" "docker-swarm-bootstrap.service" ];
      wants = [ "${stackName}-initdb.service" "docker-swarm-bootstrap.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        set -euo pipefail
        DOCKER="${pkgs.docker}/bin/docker"
        GREP="${pkgs.gnugrep}/bin/grep"

        # Require swarm active (manager)
        if ! $DOCKER info 2>/dev/null | $GREP -q "Swarm: active"; then
          echo "Swarm is not active yet; not deploying stack."
          exit 0
        fi

        # Ensure password file exists
        if [ ! -r "${cfg.dbPasswordFile}" ]; then
          echo "Missing DB password file at ${cfg.dbPasswordFile}"
          echo "Create it (0400 root:root), then run: systemctl start ${stackName}-deploy"
          exit 1
        fi

        # Create secret if missing (or recreate if you want rotation behavior)
        if ! $DOCKER secret ls --format '{{.Name}}' | $GREP -qx "${secretName}"; then
          echo "Creating swarm secret ${secretName}..."
          $DOCKER secret create "${secretName}" "${cfg.dbPasswordFile}"
        else
          echo "Swarm secret ${secretName} already exists; leaving it as-is."
        fi

        echo "Deploying stack ${stackName}..."
        $DOCKER stack deploy -c "${stackFile}" "${stackName}"
      '';
    };

    systemd.services."${stackName}-initdb" = {
      description = "Generate Guacamole DB init SQL for ${stackName}";
      wantedBy = [ "multi-user.target" ];
      wants = [ "docker.service" ];
      after = [ "docker.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        set -euo pipefail
        DOCKER="${pkgs.docker}/bin/docker"

        if [ -s "${initSql}" ]; then
          echo "${initSql} already exists; skipping generation."
          exit 0
        fi

        echo "Generating Guacamole MySQL/MariaDB init SQL at ${initSql}..."
        umask 077
        tmp="$(mktemp)"

        # Pull/generate schema SQL from the Guacamole image
        $DOCKER run --rm "${cfg.guacamoleImage}" /opt/guacamole/bin/initdb.sh --mysql > "$tmp"

        # Move into place with strict perms
        install -m 0440 -o root -g root "$tmp" "${initSql}"
        rm -f "$tmp"
      '';
    };
  };
}