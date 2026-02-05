{
  description = "Minimal NixOS VM configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    quickshell.url = "github:outfoxxed/quickshell";
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    nixosConfigurations.generic = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: 
        let
          # --- Package & Font Categorization ---
          
          fontsList = with pkgs; [
            nerd-fonts.fira-code
            nerd-fonts.caskaydia-cove
            nerd-fonts.roboto-mono
            scheherazade-new
            noto-fonts
            noto-fonts-color-emoji
            corefonts
            liberation_ttf
            material-icons
            material-symbols
            freefont_ttf
            inter
            source-code-pro
          ];

          coreTools = with pkgs; [
            git curl wget zip _7zz zoxide just inotify-tools 
            bat eza fd ripgrep dysk
          ];

          desktopEnv = with pkgs; [
            kitty starship fastfetch 
            bibata-cursors tela-circle-icon-theme 
            xdg-terminal-exec qt6Packages.qt6ct qt6Packages.qtstyleplugin-kvantum
            brightnessctl cliphist
            inputs.quickshell.packages."${pkgs.stdenv.hostPlatform.system}".default
          ];

          applications = with pkgs; [
            neovim qbittorrent vesktop slack telegram-desktop
            mpv mpvScripts.mpris
            inputs.zen-browser.packages."${pkgs.stdenv.hostPlatform.system}".beta
          ];

          devTools = with pkgs; [
            rustup mold mariadb docker-compose gpu-screen-recorder
          ];

        in {
          # ====================================================================
          # SYSTEM CORE
          # ====================================================================

          system.stateVersion = "25.11";

          nix.settings = {
            experimental-features = [ "nix-command" "flakes" ];
            auto-optimise-store = true;
            warn-dirty = false;
          };

          nix.gc = {
            automatic = true;
            dates = "weekly";
            options = "--delete-older-than 7d";
          };

          nixpkgs.config.allowUnfree = true;

          # ====================================================================
          # BOOT & HARDWARE
          # ====================================================================

          boot = {
            loader = {
              systemd-boot.enable = true;
              efi.canTouchEfiVariables = true;
              timeout = 0;
            };
            plymouth = {
              enable = true;
              theme = "spinner";
            };
            initrd = {
              systemd.enable = true;
              verbose = false;
            };
            consoleLogLevel = 0;
            kernelParams = [ 
              "quiet" "splash" "loglevel=3" "nowatchdog"
            ];
          };

          zramSwap.enable = true;
          services.qemuGuest.enable = true;

          fileSystems."/" = {
            device = "/dev/disk/by-label/nixos";
            fsType = "ext4";
          };

          networking = {
            hostName = "nixos";
            networkmanager.enable = true;
            dhcpcd.enable = false;
          };

          hardware.bluetooth.enable = true;

          # ====================================================================
          # SERVICES & MULTIMEDIA
          # ====================================================================

          security.rtkit.enable = true;
          services.pipewire = {
            enable = true;
            alsa.enable = true;
            alsa.support32Bit = true;
            pulse.enable = true;
            jack.enable = true;
            wireplumber.enable = true;
          };

          virtualisation.docker.rootless = {
            enable = true;
            setSocketVariable = true;
          };

          # ====================================================================
          # USER CONFIG & PROGRAMS
          # ====================================================================

          users.users.anas = {
            isNormalUser = true;
            extraGroups = [ "wheel" "networkmanager" ];
            password = "nixos";
          };

          programs = {
            fish.enable = true;
            bash.completion.enable = true;
            kdeconnect.enable = true;
            nano.enable = false;
          };

          documentation = {
            enable = false;
            doc.enable = false;
            man.enable = false;
            nixos.enable = false;
          };

          # ====================================================================
          # ENVIRONMENT & PACKAGES
          # ====================================================================

          fonts.packages = fontsList;

          environment.systemPackages = coreTools ++ desktopEnv ++ applications ++ devTools;
        })
      ];
    };
  };
}