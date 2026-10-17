{
  lib,
  stdenvNoCC,
  src,
}:

stdenvNoCC.mkDerivation {
  pname = "brcm-firmware-amlogic";
  version = src.rev;
  inherit src;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm644 firmware/brcm/BCM4362A2.hcd \
      $out/lib/firmware/brcm/BCM4362A2.hcd
    runHook postInstall
  '';

  meta = {
    description = "Broadcom Bluetooth firmware for the Ugoos AM9 Pro";
    homepage = "https://github.com/CoreELEC/brcmfmac_sdio-firmware-aml";
    license = lib.licenses.unfreeRedistributableFirmware;
    platforms = lib.intersectLists lib.platforms.aarch64 lib.platforms.linux;
  };
}
