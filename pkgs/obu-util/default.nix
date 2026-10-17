{
  coreelecSource,
  lib,
  stdenv,
}:

stdenv.mkDerivation {
  pname = "obu-util-coreelec";
  version = coreelecSource.rev;
  src = coreelecSource;

  sourceRoot = "source/projects/Amlogic-ce/packages/multimedia/obu_util/sources";

  buildPhase = ''
    runHook preBuild
    $CC -I. $CFLAGS -c *.c
    $AR rcs libobu_util.a *.o
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm644 libobu_util.a $out/lib/libobu_util.a
    install -Dm644 obu_util.h aom_codec.h aom_image.h aom_integer.h -t $out/include
    runHook postInstall
  '';

  meta = {
    description = "CoreELEC AV1 Open Bitstream Unit parsing library";
    homepage = "https://github.com/CoreELEC/CoreELEC";
    license = lib.licenses.bsd2;
    platforms = lib.platforms.linux;
  };
}
