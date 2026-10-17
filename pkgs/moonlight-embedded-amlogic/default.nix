{
  fetchFromGitHub,
  lib,
  makeWrapper,
  moonlight-embedded,
  libamcodec,
  alsa-lib-amlogic,
}:

(moonlight-embedded.override { alsa-lib = alsa-lib-amlogic; }).overrideAttrs (old: {
  pname = "moonlight-embedded-amlogic";
  version = "2.7.1";

  # 2.7.0 assigns the result of `xml_status(...) != GS_OK` instead of the
  # actual error code. A Sunshine launch-permission denial therefore looks
  # successful and Moonlight attempts RTSP without a session URL. 2.7.1 fixes
  # that error path and includes the corresponding common-client update.
  src = fetchFromGitHub {
    owner = "moonlight-stream";
    repo = "moonlight-embedded";
    tag = "v2.7.1";
    hash = "sha256-h+hI9TQUGMI8VDzvnuRGDjxm8D7GuC/L4/0rwTFocgA=";
    fetchSubmodules = true;
  };

  patches = (old.patches or [ ]) ++ [
    ./amlogic-api-v2.patch
    ./amlogic-decoder-control.patch
    ./amlogic-freerun.patch
    ./amlogic-modern-h264.patch
  ];

  postPatch = (old.postPatch or "") + ''
    test "$(grep -c 'codecParam.video_path         = FRAME_BASE_PATH_TUNNEL_MODE;' src/video/aml.c)" -eq 1
    test "$(grep -c 'codecParam.video_path == FRAME_BASE_PATH_AMLVIDEO_AMVIDEO' src/video/aml.c)" -eq 1
  '';

  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ makeWrapper ];
  buildInputs = (old.buildInputs or [ ]) ++ [ libamcodec ];

  cmakeFlags = (old.cmakeFlags or [ ]) ++ [
    "-DENABLE_SDL=OFF"
    "-DENABLE_FFMPEG=OFF"
    "-DENABLE_X11=OFF"
    "-DENABLE_PULSE=OFF"
    "-DENABLE_CEC=ON"
    "-DAMLOGIC_INCLUDE_DIR=${libamcodec}/include/amcodec"
    "-DAMCODEC_LIBRARY=${libamcodec}/lib/libamcodec.so"
  ];

  postInstall = (old.postInstall or "") + ''
    test -x "$out/bin/moonlight"
    test -f "$out/lib/libmoonlight-aml.so"
    wrapProgram "$out/bin/moonlight" \
      --prefix LD_LIBRARY_PATH : "$out/lib:${libamcodec}/lib" \
      --prefix XDG_DATA_DIRS : "$out/share"
  '';

  meta = (old.meta or { }) // {
    description = "Moonlight Embedded with the native Amlogic libamcodec backend";
    platforms = lib.intersectLists lib.platforms.aarch64 lib.platforms.linux;
  };
})
