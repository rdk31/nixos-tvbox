{
  lib,
  stdenvNoCC,

  autoPatchelfHook,
  coreelecSource,
}:

stdenvNoCC.mkDerivation {
  pname = "opentee-amlogic";
  version = coreelecSource.rev;
  src = coreelecSource;

  nativeBuildInputs = [ autoPatchelfHook ];
  sourceRoot = "source/projects/Amlogic-ce/packages/linux-drivers/amlogic/opentee_linuxdriver";
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 -t "$out/bin" \
      filesystem/aarch64/usr/sbin/tee-supplicant \
      filesystem/aarch64/usr/sbin/tee_preload_fw
    install -Dm644 -t "$out/lib" \
      filesystem/aarch64/usr/lib/libtee_preload_fw.so \
      filesystem/aarch64/usr/lib/libteec.so.1.0.0
    ln -s libteec.so.1.0.0 "$out/lib/libteec.so.1"
    ln -s libteec.so.1 "$out/lib/libteec.so"
    install -Dm644 \
      filesystem/aarch64/ta/v3.8/dev/S905X5/526fc4fc-7ee6-4a12-96e3-83da9565bce8.ta \
      "$out/lib/optee_armtz/S905X5/526fc4fc-7ee6-4a12-96e3-83da9565bce8.ta"

    runHook postInstall
  '';

  meta = {
    description = "CoreELEC OP-TEE video firmware preload userspace";
    homepage = "https://github.com/CoreELEC/CoreELEC";
    license = lib.licenses.gpl2Plus;
    platforms = lib.intersectLists lib.platforms.aarch64 lib.platforms.linux;
  };
}
