{ pkgs, ... }: {
  virtualisation.containers.enable = true;
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    dockerSocket.enable = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  environment.systemPackages = with pkgs; [
    oxker
    ducker
    mariadb.client
  ];

  virtualisation.oci-containers = {
    backend = "podman";
    containers = {
      mariadb = {
        image = "mariadb:lts";
        extraOptions = [ "--network=host" ];
        environment = {
          MYSQL_ROOT_PASSWORD = "root";
          MYSQL_ROOT_HOST = "%";
        };
        volumes = [
          "mariadb_data:/var/lib/mysql"
          "/mnt/Work/0Coding/0SacredCube/DB/July25.sql:/docker-entrypoint-initdb.d/init.sql"
        ];
        cmd = [ "--innodb-buffer-pool-size=512M" ];
      };

      valkey = {
        image = "valkey/valkey:alpine";
        extraOptions = [ "--network=host" ];
        volumes = [ "valkey_data:/data" ];
      };

      mailpit = {
        image = "axllent/mailpit:latest";
        extraOptions = [ "--network=host" ];
        environment = { TZ = "UTC+2"; };
        volumes = [ "mailpit_data:/data" ];
      };

      watchtower = {
        image = "nickfedor/watchtower";
        extraOptions = [ "--network=host" ];
        environment = {
          WATCHTOWER_CLEANUP = "1";
          WATCHTOWER_POLL_INTERVAL = "14400";
        };
        volumes = [ "/var/run/docker.sock:/var/run/docker.sock" ];
      };
    };
  };
}
