{
  lib,
  stdenv,
  pkg-config,
  libdrm,
}:

stdenv.mkDerivation {
  pname = "amlogic-drm-session";
  version = "1";
  src = ./session.c;
  dontUnpack = true;
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ libdrm ];
  buildPhase = ''
    $CC -std=c11 -Wall -Wextra -Werror $src -o amlogic-drm-session $(pkg-config --cflags --libs libdrm)
  '';
  installPhase = ''
    install -Dm755 amlogic-drm-session $out/bin/amlogic-drm-session
  '';
  meta = {
    description = "Keep Amlogic HDMI active while a native video frontend runs";
    platforms = lib.platforms.linux;
    mainProgram = "amlogic-drm-session";
  };
}
