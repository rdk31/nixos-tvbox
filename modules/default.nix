{ lib, ... }:

{
  imports = [
    ./tvbox/frontend.nix
    ./tvbox/kodi.nix
    ./tvbox/hyperhdr.nix
    ./tvbox/moonlight.nix
  ];

  nixpkgs.config.allowUnfreePredicate = lib.mkDefault (
    pkg:
    builtins.elem (lib.getName pkg) [
      "amremote"
      "dovi-module-external"
      "libamcodec"
      "libmali-g310"
    ]
  );
}
