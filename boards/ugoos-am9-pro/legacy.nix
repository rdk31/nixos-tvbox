{ pkgs, ... }:

{
  boot.kernelPackages = pkgs.linuxPackagesForAmlogic (
    pkgs.linux-amlogic.override { legacyBootloader = true; }
  );
}
