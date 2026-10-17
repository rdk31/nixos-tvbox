inputs: final: prev:

prev.lib.composeManyExtensions [
  (import ./packages.nix inputs)
  (import ./kernel-packages.nix inputs)
  (import ./kodi.nix inputs)
] final prev
