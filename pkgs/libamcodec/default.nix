{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "libamcodec";
  version = "d28bf07facc8727de52ba1f70c1362f9e19adc25";
  src = fetchurl {
    url = "https://sources.coreelec.org/libamcodec-aarch64-${finalAttrs.version}.tar.xz";
    hash = "sha256-UxNLORJaxcPUM4zeV8bsREFUYo/hfcGoCKmO8XGykU4=";
  };

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
