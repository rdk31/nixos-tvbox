{
  lib,
  pkgs,
  ...
}:

{
  boot.kernelPackages = lib.mkDefault (pkgs.linuxPackagesForAmlogic pkgs.linux-amlogic);

  assertions = [
    {
      assertion = pkgs.stdenv.hostPlatform.system == "aarch64-linux";
      message = "The Amlogic S905X5 profile supports only aarch64-linux.";
    }
  ];
}
