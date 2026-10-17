{
  config,
  lib,
  ...
}:

{
  options.hardware.amlogic.dolbyVision.enable = lib.mkEnableOption "Dolby Vision support";

  config = lib.mkIf config.hardware.amlogic.dolbyVision.enable {
    boot.extraModulePackages = [ config.boot.kernelPackages.dovi-module ];
    boot.kernelModules = [ "dovi" ];

    environment.etc."nixos-tvbox/dolby-vision-status".text =
      "dovi.ko fetched from CoreELEC; vendor-kernel compatibility verified at build time.\n";
  };
}
