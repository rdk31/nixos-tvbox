{
  lib,
  callPackage,
  fetchurl,

  src,

  alsa-lib-amlogic,
  bison,
  coreelecSource,
  crossguid,
  exiv2,
  ffmpeg,
  fmt,
  kodi-gbm,
  libamcodec,
  libbluray,
  libcec,
  libdovi,
  libmali,
  meson,
  ninja,
  nlohmann_json,
  obuUtil,
  pcre2,
  wayland,
}:

let
  bluray = callPackage ./overrides/libbluray.nix { inherit libbluray coreelecSource; };
  cec = callPackage ./overrides/libcec.nix { inherit libcec; };
  swigSource = fetchurl {
    url = "https://mirrors.kodi.tv/build-deps/sources/swig-4.5.0.tar.gz";
    hash = "sha512-/vfD25nSiUBkrIze2YncV0/BW4pJfbYjnieOMmYWyQXfjC0qKISPbgh0wXMq+Vh3LVBNqExfBotxmk0ZKkculg==";
  };
  kodiBase = kodi-gbm.override {
    inherit ffmpeg;
    alsa-lib = alsa-lib-amlogic;
    libcec = cec;
    libcrossguid = crossguid;
  };
  kodi = kodiBase.overrideAttrs (
    finalAttrs: old: {
      version = "22.0-coreelec-${builtins.substring 0 7 src.rev}";
      kodiReleaseName = "Piers";
      # Kodi's native tools use src.name to locate their source directories.
      src = src // {
        name = "source";
      };
      # Match the Meson-based DVD sources in this Kodi fork's tools/depends.
      libdvdcss = fetchurl {
        url = "https://mirrors.kodi.tv/build-deps/sources/libdvdcss-1.5.0.tar.bz2";
        hash = "sha512-Q5+9na5guaEU00KaGXA0eMc06FJaxoUtpvBfctnKRMoKxeh0q2oQAX5/MYafzSnwHRvBVsTwMxtOSr2Y7C+VzQ==";
      };
      libdvdread = fetchurl {
        url = "https://mirrors.kodi.tv/build-deps/sources/libdvdread-7.0.1.tar.bz2";
        hash = "sha512-tTkKGsuP324kGI+SWRmesP7y3UszJEe6K/pXH5/Aw7+tAMHSeouIBhgKhTwEqBi3gC0wdf94cULBoXWteYxqPQ==";
      };
      libdvdnav = fetchurl {
        url = "https://mirrors.kodi.tv/build-deps/sources/libdvdnav-7.0.0.tar.bz2";
        hash = "sha512-jRLUduNS3vlxbsvXuhhKcN2brofc3mabhkeg75rBmR9hfJkYwEPhWes1MwLEzFD7cbxZHOrrodO51Hr3f6cscQ==";
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
      ];
      # This target disables Kodi's CMake test suite below, so do not run the
      # generic stdenv check phase either.
      doCheck = false;

      nativeBuildInputs = old.nativeBuildInputs ++ [ bison ];

      buildInputs =
        builtins.filter (
          package:
          !builtins.elem (lib.getName package) [
            "libbluray"
            "libcec"
          ]
        ) old.buildInputs
        ++ [
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
        (lib.cmakeBool "ENABLE_INTERNAL_SWIG" true)
        (lib.cmakeFeature "SWIG_URL" (toString swigSource))
        (lib.cmakeFeature "LIBDVDCSS_URL" (toString finalAttrs.libdvdcss))
        (lib.cmakeFeature "LIBDVDREAD_URL" (toString finalAttrs.libdvdread))
        (lib.cmakeFeature "LIBDVDNAV_URL" (toString finalAttrs.libdvdnav))
        (lib.cmakeBool "ENABLE_TESTING" false)
        (lib.cmakeFeature "MESON_EXECUTABLE" (lib.getExe meson))
        (lib.cmakeFeature "NINJA_EXECUTABLE" (lib.getExe ninja))
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
    }
  );
in
{
  inherit
    kodi
    ffmpeg
    ;
}
