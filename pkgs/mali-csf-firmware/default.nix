{
  coreelecSource,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "mali-csf-firmware";
  version = coreelecSource.rev;
  dontConfigure = true;
  dontBuild = true;
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    install -Dm644 \
      ${coreelecSource}/packages/linux-firmware/kernel-firmware/sources/arm/mali/arch10.8/mali_csffw.bin \
      $out/lib/firmware/arm/mali/arch10.8/mali_csffw.bin
    ln -s arm/mali/arch10.8/mali_csffw.bin \
      $out/lib/firmware/mali_csffw.bin
    runHook postInstall
  '';

  meta = {
    description = "Firmware for Arm Mali CSF GPUs";
    homepage = "https://github.com/CoreELEC/CoreELEC/tree/coreelec-22/packages/linux-firmware/kernel-firmware/sources/arm/mali/arch10.8";
    license = lib.licenses.unfreeRedistributableFirmware;
    platforms = lib.intersectLists lib.platforms.aarch64 lib.platforms.linux;
  };
}
