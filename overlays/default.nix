inputs: final: prev:

prev.lib.composeManyExtensions [
  (_: previous: {
    lib = previous.lib.extend (import ../lib);
    coreelecSources = import ./coreelec-sources.nix {
      inherit (final) lib fetchurl;
      coreelecSource = inputs.coreelec;
    };
  })
  (import ./packages.nix inputs)
  (import ./kernel-packages.nix)
  (import ./kodi.nix inputs)
] final prev
