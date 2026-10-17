{ lib, ... }:

{
  imports = [
    ../../modules/amlogic/s905x5
    ./remote.nix
    ./boot.nix
    ./sd-boot.nix
  ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
