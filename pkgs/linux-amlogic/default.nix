{
  lib,
  linuxManualConfig,
  runCommand,

  linuxSource,
  commonDriversSource,

  legacyBootloader ? false,
  features ? { },
  kernelPatches ? [ ],
  randstructSeed ? "",
}:

let
  version = "5.15.196";
  composedSource = runCommand "linux-amlogic-${version}-source" { } ''
    cp -a ${linuxSource} $out
    chmod -R u+w $out
    mkdir -p $out/common_drivers
    cp -a ${commonDriversSource}/. $out/common_drivers/
    chmod -R u+w $out/common_drivers
  '';
in
linuxManualConfig {
  pname = "linux-amlogic-ugoos-am9-pro";
  inherit version;
  modDirVersion = version;
  src = composedSource;
  configfile = ./kernel.config;
  target = "Image";
  inherit features randstructSeed;
  # Stock AM9 firmware before 2.2.0 needs edge-triggered S6 interrupts.
  # Keep this alongside the newer drivers required by Kodi's Dolby Vision API.
  kernelPatches =
    lib.optionals legacyBootloader [
      {
        name = "s6-legacy-bootloader-irqs";
        patch = ./s6-legacy-bootloader-irqs.patch;
      }
    ]
    ++ kernelPatches;
  extraMeta = {
    description = "CoreELEC-derived Amlogic 5.15 kernel for the Ugoos AM9 Pro";
    platforms = lib.intersectLists lib.platforms.aarch64 lib.platforms.linux;
    license = lib.licenses.gpl2Only;
  };
}
