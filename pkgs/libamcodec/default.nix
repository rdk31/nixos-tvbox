{
  lib,
  stdenvNoCC,
  src,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "libamcodec";
  version = src.rev;
  inherit src;

  sourceRoot = "libamcodec-aarch64-${finalAttrs.version}";
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    test -f usr/lib/libamcodec.so
    test -f usr/include/amcodec/codec_error.h
    mkdir -p $out
    cp -r usr/include usr/lib $out/
    runHook postInstall
  '';

  meta = {
    description = "CoreELEC Amlogic codec interface library";
    homepage = "https://github.com/CoreELEC/CoreELEC";
    license = lib.licenses.unfree;
    platforms = lib.intersectLists lib.platforms.aarch64 lib.platforms.linux;
  };
})
