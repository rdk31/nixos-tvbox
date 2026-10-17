{
  lib,
  fetchurl,
  coreelecSource,
}:

let
  fetchPackage =
    relativePath:
    let
      path = "${coreelecSource}/projects/Amlogic-ce/packages/${relativePath}/package.mk";
      package = lib.readPackageMk path;
      github = builtins.match "https://github.com/([^/]+)/([^/]+)/archive/([0-9a-f]{40})\\.tar\\.gz" package.PKG_URL;
    in
    if github != null then
      if builtins.elemAt github 2 != package.PKG_VERSION then
        throw "${path}: PKG_URL does not match PKG_VERSION"
      else
        builtins.fetchTree {
          type = "github";
          owner = builtins.elemAt github 0;
          repo = builtins.elemAt github 1;
          rev = package.PKG_VERSION;
        }
    else if builtins.match "[0-9a-f]{64}" package.PKG_SHA256 == null then
      throw "${path}: expected a GitHub commit archive or an archive with PKG_SHA256"
    else
      (fetchurl {
        url = package.PKG_URL;
        hash = builtins.convertHash {
          hash = package.PKG_SHA256;
          hashAlgo = "sha256";
          toHashFormat = "sri";
        };
      })
      // {
        rev = package.PKG_VERSION;
      };
in
lib.mapAttrs (_: fetchPackage) {
  linux-amlogic = "linux";
  common-drivers = "linux-drivers/amlogic/common_drivers";
  amremote = "sysutils/amremote";
  brcm-firmware = "linux-firmware/brcmfmac_sdio-firmware-aml";
  libmali = "opengl-meson";
  gpu-aml = "linux-drivers/gpu-aml";
  media-modules-aml = "linux-drivers/amlogic/media_modules-aml";
  kodi = "mediacenter/kodi";
  libamcodec = "multimedia/libamcodec";
}
