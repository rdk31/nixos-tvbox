{
  lib,
  hyperhdr,
  openssl,
  zstd,
}:

hyperhdr.overrideAttrs (old: {
  pname = "hyperhdr-amlogic";
  patches = (old.patches or [ ]) ++ [
    ./video-only-auto-hdr.patch
    ./clear-idle-video.patch
  ];
  # PipeWire is disabled, so skip nixpkgs' PipeWire plugin RPATH fixup.
  postFixup = "";
  postInstall = (old.postInstall or "") + ''
    mkdir -p "$out/lut"
    tar -xJOf "$NIX_BUILD_TOP/$sourceRoot/resources/lut/lut_lin_tables.tar.xz" lut_lin_tables.3d \
      | zstd -19 -T0 -o "$out/lut/lut_lin_tables.3d.zst"
  '';
  buildInputs = old.buildInputs ++ [
    openssl
    zstd
  ];
  cmakeFlags =
    builtins.filter (
      flag: !(lib.hasPrefix "-DPLATFORM=" flag) && !(lib.hasPrefix "-DUSE_SYSTEM_MBEDTLS_LIBS" flag)
    ) old.cmakeFlags
    ++ [
      "-DPLATFORM=amlogic64"
      "-DENABLE_AMLOGIC=ON"
      "-DENABLE_PIPEWIRE=OFF"
      "-DENABLE_PIPEWIRE_EGL=OFF"
      "-DENABLE_X11=OFF"
      "-DENABLE_SYSTRAY=OFF"
      "-DENABLE_CEC=OFF"
      "-DENABLE_SOUNDCAPLINUX=OFF"
    ];
})
