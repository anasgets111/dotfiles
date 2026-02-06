{ config, pkgs, lib, ... }:
let
  # PHP 8.4 with all requested extensions + defaults
  myPhp = pkgs.php84.withExtensions ({ enabled, all }: 
    enabled ++ (with all; [
      gd imagick redis sodium xsl igbinary pgsql snmp sqlite3
      bcmath bz2 curl intl mbstring mysqli openssl pdo_mysql pdo_pgsql pdo_sqlite zlib zip
    ])
  );

  # --- YOUR PROJECTS HERE ---
  # Key = domain prefix (e.g., "cube" -> cube.test)
  # Value = either a local path (string) or a port number (int)
  projects = {
    "sacredcube" = "/mnt/Work/0Coding/0SacredCube/erp/public";
    # "my-proxy"   = 3000;
  };
  # --------------------------

  # Helper to generate Nginx vhost config
  mkVhost = name: target: 
    let
      domain = "${name}.test";
      # Paths for mkcert certificates
      certDir = "/var/lib/mkcert";
    in {
      name = domain;
      value = {
        addSSL = true;
        sslCertificate = "${certDir}/${domain}.pem";
        sslCertificateKey = "${certDir}/${domain}-key.pem";
        
        # If target is a number, treat as Reverse Proxy
        # If target is a string, treat as local PHP root
        locations."/" = if lib.isInt target then {
          proxyPass = "http://127.0.0.1:${toString target}";
          proxyWebsockets = true;
        } else {
          root = target;
          index = "index.php index.html";
          extraConfig = ''
            try_files $uri $uri/ /index.php?$query_string;
          '';
        };

        # PHP-FPM configuration (only if not a proxy)
        locations."~ \\.php$" = lib.mkIf (!lib.isInt target) {
          extraConfig = ''
            fastcgi_pass unix:${config.services.phpfpm.pools.mypool.socket};
            fastcgi_index index.php;
            include ${pkgs.nginx}/conf/fastcgi_params;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
          '';
        };
      };
    };

in {
  environment.systemPackages = [ 
    myPhp 
    myPhp.packages.composer 
    pkgs.mkcert
  ];

  # 1. DNS: .test resolution via dnsmasq
  services.dnsmasq = {
    enable = true;
    settings = {
      address = "/.test/127.0.0.1";
    };
  };

  # 2. PHP-FPM: User-specific pool
  services.phpfpm.pools.mypool = {
    user = "anas";
    settings = {
      "listen.owner" = "nginx";
      "listen.group" = "nginx";
      "pm" = "dynamic";
      "pm.max_children" = 10;
      "pm.start_servers" = 2;
      "pm.min_spare_servers" = 1;
      "pm.max_spare_servers" = 3;
    };
  };

  # 3. NGINX: Generate virtual hosts from the projects list
  services.nginx = {
    enable = true;
    # Convert projects attrset into Nginx virtualHosts
    virtualHosts = lib.listToAttrs (lib.mapAttrsToList mkVhost projects);
  };

  # 4. Automate Certificate Generation (Activation Script)
  # This creates the directory and ensures certificates exist for defined projects
  system.activationScripts.mkcert-gen = {
    supportsDryActivation = true;
    text = ''
      mkdir -p /var/lib/mkcert
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: target: ''
        if [ ! -f /var/lib/mkcert/${name}.test.pem ]; then
          ${pkgs.mkcert}/bin/mkcert -cert-file /var/lib/mkcert/${name}.test.pem \
                                    -key-file /var/lib/mkcert/${name}.test-key.pem \
                                    ${name}.test
        fi
      '') projects)}
      
      chown -R nginx:nginx /var/lib/mkcert
    '';
  };

  # Ensure Nginx has access to the certificates
  users.users.nginx.extraGroups = [ "anas" ];
}
