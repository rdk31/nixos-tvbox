{
  lib,
  hyperhdr,
  fetchFromGitHub,
  openssl,
  zstd,
}:

hyperhdr.overrideAttrs (old: {
  pname = "hyperhdr-amlogic";
  version = "22.0.0.0";
  src = fetchFromGitHub {
    owner = "awawa-dev";
    repo = "HyperHDR";
    tag = "v22.0.0.0";
    hash = "sha256-si39Q5XaZHGAFEU2sqU60+5kPYVPnTAoPaiyWD1Dlvs=";
  };
  # The v21 unvendoring patch is included upstream in v22.
  patches = [
    ./video-only-auto-hdr.patch
    ./clear-idle-video.patch
  ];
  postPatch = (old.postPatch or "") + ''
    substituteInPlace sources/hyperhdr/CMakeLists.txt \
      --replace-fail 'INSTALL_RPATH_USE_LINK_PATH FALSE' 'INSTALL_RPATH_USE_LINK_PATH TRUE'
  '';
  preFixup = (old.preFixup or "") + ''
    qtWrapperArgs+=(--prefix LD_LIBRARY_PATH : "$out/lib")
  '';
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
