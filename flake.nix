{
  description = "NixOS TV-box modules";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    coreelec = {
      url = "github:CoreELEC/CoreELEC/coreelec-22";
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
        ./checks.nix
        git-hooks.flakeModule
        treefmt-nix.flakeModule
      ];
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];

      flake = {
        lib = nixpkgs.lib.extend (import ./lib);
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
              linux-amlogic
              mali-csf-firmware
              obu-util
              opentee-amlogic
              ;

            kodi-amlogic = targetPkgs.kodi-amlogic.kodi;
            kodi-youtube = targetPkgs.kodi-addons.youtube;
            kodi-frontend-launcher = targetPkgs.kodi-addons.frontend-launcher;
            libbluray = targetPkgs.callPackage ./pkgs/kodi-amlogic/overrides/libbluray.nix {
              coreelecSource = coreelec;
            };
          };
        };
    };
}
