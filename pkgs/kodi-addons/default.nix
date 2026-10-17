{
  callPackage,

  kodi,
}:

{
  frontend-launcher = kodi.packages.callPackage ./frontend-launcher { };
  youtube = callPackage ./youtube.nix { inherit kodi; };
}
