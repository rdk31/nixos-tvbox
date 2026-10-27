{
  inputs,
  self,
  ...
}:

let
  board = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.ugoos-am9-pro
      { system.stateVersion = "26.05"; }
    ];
  };
  allFeatures = board.extendModules {
    modules = [
      {
        hardware.amlogic.dolbyVision.enable = true;
        nixos-tvbox = {
          kodi.jellyfin.enable = true;
          kodi.youtube.enable = true;
          moonlight.enable = true;
          hyperhdr = {
            enable = true;
            openFirewall = true;
          };
        };
      }
    ];
  };
  image = allFeatures.extendModules {
    modules = [ self.nixosModules.ugoos-am9-pro-image ];
  };
in
{
  flake.nixosConfigurations.ugoos-am9-pro-ci = allFeatures;

  perSystem =
    { pkgs, ... }:
    {
      checks.module-evaluation =
        assert builtins.all (n: builtins.isString n.config.system.build.toplevel.drvPath) [
          board
          allFeatures
          image
        ];
        assert builtins.isString image.config.system.build.sdImage.drvPath;
        pkgs.runCommand "tvbox-module-evaluation" { } "touch $out";
    };
}
