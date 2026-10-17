{
  description = "NixOS TV-box modules";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    coreelec = {
      url = "github:CoreELEC/CoreELEC/coreelec-22";
      flake = false;
    };
    coreelec-linux-amlogic = {
      url = "github:CoreELEC/linux-amlogic/5.15.196_20260306";
      flake = false;
    };
    coreelec-common-drivers = {
      url = "github:CoreELEC/common_drivers/5.15.196_20260225";
      flake = false;
    };
    coreelec-amremote = {
      url = "github:CoreELEC/amremote/linux-5.15";
      flake = false;
    };
    coreelec-brcm-firmware = {
      url = "github:CoreELEC/brcmfmac_sdio-firmware-aml/master";
      flake = false;
    };
    coreelec-libmali = {
      url = "github:CoreELEC/opengl-meson/r44p0";
      flake = false;
    };
    coreelec-gpu-aml = {
      url = "github:CoreELEC/gpu-aml/r44p0-5.15.196";
      flake = false;
    };
    coreelec-media-modules-aml = {
      url = "github:CoreELEC/media_modules-aml/5.15.196_20260225";
      flake = false;
    };
    coreelec-kodi = {
      url = "github:CoreELEC/xbmc/aml-5.15.196-22.0";
      flake = false;
    };

    flake-parts.url = "github:hercules-ci/flake-parts";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      coreelec,
      flake-parts,
      git-hooks,
      nixpkgs,
      self,
      treefmt-nix,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        git-hooks.flakeModule
        treefmt-nix.flakeModule
      ];
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];

      flake = {
        overlays.default = import ./overlays inputs;
        nixosModules = {
          nixos-tvbox = {
            imports = [ ./modules ];
            nixpkgs.overlays = [ self.overlays.default ];
          };
          amlogic-s905x5 = {
            imports = [
              self.nixosModules.nixos-tvbox
              ./modules/amlogic/s905x5
            ];
          };
          ugoos-am9-pro = {
            imports = [
              self.nixosModules.nixos-tvbox
              ./boards/ugoos-am9-pro
            ];
          };
          ugoos-am9-pro-image = {
            imports = [
              self.nixosModules.ugoos-am9-pro
              ./boards/ugoos-am9-pro/image.nix
            ];
          };
        };
      };

      perSystem =
        {
          config,
          lib,
          pkgs,
          system,
          ...
        }:
        let
          targetPkgs = import nixpkgs {
            system = "aarch64-linux";
            overlays = [ self.overlays.default ];
            config.allowUnfreePredicate =
              pkg:
              builtins.elem (nixpkgs.lib.getName pkg) [
                "amremote"
                "dovi-module-external"
                "libamcodec"
                "libmali-g310"
              ];
          };
          targetKernelPackages = targetPkgs.linuxPackagesForAmlogic targetPkgs.linux-amlogic;
        in
        {
          pre-commit = {
            check.enable = true;
            settings.hooks = {
              shellcheck.enable = true;
              treefmt.enable = true;
            };
          };

          devShells.default = pkgs.mkShell {
            packages = [
              pkgs.git
              pkgs.nix
              pkgs.nixos-rebuild
              pkgs.openssh
            ]
            ++ config.pre-commit.settings.enabledPackages;
            shellHook = config.pre-commit.shellHook;
          };

          treefmt = {
            projectRootFile = "flake.nix";
            programs = {
              deadnix.enable = true;
              nixfmt.enable = true;
              shfmt.enable = true;
              statix.enable = true;
            };
          };

          packages = lib.optionalAttrs (system == "aarch64-linux") {
            inherit (targetKernelPackages) dovi-module;

            inherit (targetPkgs)
              amlogic-drm-session
              hyperhdr-amlogic
              moonlight-embedded-amlogic
              amremote
              brcm-firmware-amlogic
              libamcodec
              libmali
              mali-csf-firmware
              obu-util
              opentee-amlogic
              ;

            kodi-youtube = targetPkgs.kodi-addons.youtube;
            kodi-frontend-launcher = targetPkgs.kodi-addons.frontend-launcher;
            libbluray = targetPkgs.callPackage ./pkgs/kodi-amlogic/overrides/libbluray.nix {
              coreelecSource = coreelec;
            };
          };

          checks =
            import ./checks { inherit self nixpkgs pkgs; }
            // lib.optionalAttrs (system == "aarch64-linux") config.packages;
        };
    };
}
