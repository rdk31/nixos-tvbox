{
  lib,
  stdenvNoCC,
  src,
}:

stdenvNoCC.mkDerivation {
  pname = "libmali-g310";
  version = src.rev;
  inherit src;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 \
      lib/arm64/valhall/r44p0/wayland/libMali_g310_dmaheap.so \
      $out/lib/libMali.so.1
    ln -s libMali.so.1 $out/lib/libMali.so
    ln -s libMali.so.1 $out/lib/libEGL.so.1
    ln -s libMali.so.1 $out/lib/libGLESv2.so.2
    ln -s libMali.so.1 $out/lib/libgbm.so
    ln -s libMali.so.1 $out/lib/libgbm.so.1
    runHook postInstall
  '';

  meta = {
    description = "CoreELEC Mali-G310 r44p0 Wayland userspace driver";
    homepage = "https://github.com/CoreELEC/opengl-meson";
    license = lib.licenses.unfree;
    platforms = lib.intersectLists lib.platforms.aarch64 lib.platforms.linux;
  };
}
