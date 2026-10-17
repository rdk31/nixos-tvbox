{
  lib,
  stdenv,
  src,
}:

stdenv.mkDerivation {
  pname = "amremote";
  version = src.rev;
  inherit src;

  installPhase = ''
    runHook preInstall
    install -Dm755 remotecfg $out/bin/remotecfg
    runHook postInstall
  '';

  meta = {
    description = "Userspace configuration utility for the Amlogic infrared remote driver";
    homepage = "https://github.com/CoreELEC/amremote";
    license = lib.licenses.unfree;
    platforms = lib.platforms.linux;
    mainProgram = "remotecfg";
  };
}
