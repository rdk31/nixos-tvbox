{
  description = "NixOS TV-box modules";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    coreelec = {
      url = "github:CoreELEC/CoreELEC/8c82dbaa6160b20806917556979b2dd964a251de";
      flake = false;
    };
    coreelec-linux-amlogic = {
      url = "github:CoreELEC/linux-amlogic/799e6a3d791a34720f5ca89ef95251541e024ab3";
      flake = false;
    };
    coreelec-common-drivers = {
      url = "github:CoreELEC/common_drivers/6e10fef9b78b48060e86ea97a40eb35ddc23b0ca";
      flake = false;
    };
    coreelec-amremote = {
      url = "github:CoreELEC/amremote/c979ec379706e023471f28fc49c92633ab9a370a";
      flake = false;
    };
    coreelec-brcm-firmware = {
      url = "github:CoreELEC/brcmfmac_sdio-firmware-aml/1d4dfecc010106d651e11c2e25824dcb059e774e";
      flake = false;
    };
    coreelec-libmali = {
      url = "github:CoreELEC/opengl-meson/2e7fc9325857953a3ced495b752d42e055bc9ddc";
      flake = false;
    };
    coreelec-gpu-aml = {
      url = "github:CoreELEC/gpu-aml/8deb0c1665bfc20fb97e43650510edf3d86b0c00";
      flake = false;
    };
    coreelec-media-modules-aml = {
      url = "github:CoreELEC/media_modules-aml/6854cdcd591d4b70acb44c490700355fd8b8c512";
      flake = false;
    };
    coreelec-kodi = {
      url = "github:CoreELEC/xbmc/9f61cca98636d13425101779a2cffccbfd964f47";
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
