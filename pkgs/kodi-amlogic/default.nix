{
  lib,
  callPackage,
  fetchpatch,

  src,

  alsa-lib-amlogic,
  coreelecSource,
  exiv2,
  ffmpeg,
  fmt,
  kodi-gbm,
  libamcodec,
  libbluray,
  libcec,
  libcrossguid,
  libdovi,
  libmali,
  nlohmann_json,
  obuUtil,
  pcre2,
  wayland,
}:

let
  bluray = callPackage ./overrides/libbluray.nix { inherit libbluray coreelecSource; };
  cec = callPackage ./overrides/libcec.nix { inherit libcec; };
  crossguid = callPackage ./overrides/libcrossguid.nix { inherit libcrossguid; };
  kodiBase = kodi-gbm.override {
    inherit ffmpeg;
    alsa-lib = alsa-lib-amlogic;
    libcec = cec;
  };
  kodi = kodiBase.overrideAttrs (old: {
    version = "22.0-coreelec-${builtins.substring 0 7 src.rev}";
    kodiReleaseName = "Piers";
    # Kodi's native tools use src.name to locate their source directories.
    src = src // {
      name = "source";
    };
    # Replace nixpkgs' Kodi patches: this CoreELEC fork already carries at
    # least the giflib fix, so replaying the nixpkgs patch stack fails.
    # The local patch keeps DRM property values 64-bit through the Amlogic
    # display path.
    patches = [
      ./preserve-drm-property-width.patch
      # Mask the bottom strip on H.264 heights that are not divisible by eight,
      # restoring the previous global Amlogic crop when playback ends.
      ./h264-bottom-crop.patch
      # Pannal's patch defers master-clock anchoring during transient all-NOPTS
      # playback starts, preventing a long hardware-decoder picture freeze.
      (fetchpatch {
        url = "https://github.com/pannal/xbmc/commit/cc2fc150cd3238ededa78a1850c34e78bb30ae13.patch";
        hash = "sha256-RXqX0ASYOk6g8Lo4WZZ8e+Fiu62Hyhvd28e0zGl17Yo=";
      })
    ];
    # This target disables Kodi's CMake test suite below, so do not run the
    # generic stdenv check phase either.
    doCheck = false;

    buildInputs =
      builtins.filter (
        package:
        !builtins.elem (lib.getName package) [
          "libbluray"
          "libcec"
        ]
      ) old.buildInputs
      ++ [
        crossguid
        exiv2
        fmt
        libamcodec
        bluray
        cec
        libmali
        libdovi
        nlohmann_json
        obuUtil
        pcre2
        wayland
      ];

    NIX_LDFLAGS =
      (old.NIX_LDFLAGS or "") + " -L${libmali}/lib -lMali -lwayland-client -lwayland-server -ldrm";
    cmakeFlags = (old.cmakeFlags or [ ]) ++ [
      (lib.cmakeFeature "APP_RENDER_SYSTEM" "gles")
      (lib.cmakeBool "ENABLE_LIBDOVI" true)
      (lib.cmakeBool "ENABLE_CEC" true)
      (lib.cmakeBool "ENABLE_INTERNAL_FFMPEG" false)
      (lib.cmakeBool "ENABLE_TESTING" false)
    ];
    # nixpkgs derives this flag from its GBM/X11 support switches, but CoreELEC's
    # Amlogic platform is not represented by those switches.
    preConfigure = ''
      cmakeFlagsArray+=("-DCORE_PLATFORM_NAME=aml")
    '';

    postInstall = (old.postInstall or "") + ''
      install -m 0644 \
        ${./appliance.xml} \
        $out/share/kodi/system/settings/appliance.xml

      for program in "$out/bin/kodi" "$out/lib/kodi/kodi.bin"; do
        if [ -x "$program" ]; then
          wrapProgram "$program" \
            --prefix LD_LIBRARY_PATH : ${
              lib.makeLibraryPath [
                libamcodec
                cec
                libmali
                libdovi
              ]
            }
        fi
      done
    '';
  });
in
{
  inherit
    kodi
    ffmpeg
    ;
}
