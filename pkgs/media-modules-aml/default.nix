{
  lib,
  stdenv,
  src,

  kernel,
}:

stdenv.mkDerivation {
  pname = "media-modules-aml";
  version = src.rev;
  inherit src;

  nativeBuildInputs = kernel.moduleBuildDependencies;
  hardeningDisable = [
    "pic"
    "format"
  ];

  buildPhase = ''
    runHook preBuild
    make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
      M="$PWD/drivers" \
      CONFIG_AMLOGIC_MEDIA_VDEC_MPEG2_MULTI=m \
      CONFIG_AMLOGIC_MEDIA_VDEC_MPEG4_MULTI=m \
      CONFIG_AMLOGIC_MEDIA_VDEC_VC1=m \
      CONFIG_AMLOGIC_MEDIA_VDEC_H264_MULTI=m \
      CONFIG_AMLOGIC_MEDIA_VDEC_H264_MVC=m \
      CONFIG_AMLOGIC_MEDIA_VDEC_H265=m \
      CONFIG_AMLOGIC_MEDIA_VDEC_H266=m \
      CONFIG_AMLOGIC_MEDIA_VDEC_VP9=m \
      CONFIG_AMLOGIC_MEDIA_VDEC_MJPEG_MULTI=m \
      CONFIG_AMLOGIC_MEDIA_VDEC_AVS_MULTI=m \
      CONFIG_AMLOGIC_MEDIA_VDEC_AVS2=m \
      CONFIG_AMLOGIC_MEDIA_VDEC_AVS3=m \
      CONFIG_AMLOGIC_MEDIA_VDEC_AV1=m \
      CONFIG_AMLOGIC_MEDIA_VDEC_VP9_FB=m \
      CONFIG_AMLOGIC_MEDIA_VDEC_H265_FB=m \
      CONFIG_AMLOGIC_MEDIA_VDEC_AV1_FB=m \
      CONFIG_AMLOGIC_MEDIA_VDEC_AVS2_FB=m \
      CONFIG_AMLOGIC_HW_DEMUX=m \
      modules
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    moduleDir="$out/lib/modules/${kernel.modDirVersion}/extra/media_modules-aml"
    mkdir -p "$moduleDir" "$out/lib/firmware/video/S905X5"
    find drivers -name '*.ko' -exec install -m 0644 {} "$moduleDir" \;
    install -m 0644 firmware/S905X5/video_ucode.bin \
      "$out/lib/firmware/video/S905X5/video_ucode.bin"
    runHook postInstall
  '';

  meta = {
    description = "CoreELEC Amlogic video decoder modules and S905X5 firmware";
    homepage = "https://github.com/CoreELEC/media_modules-aml";
    license = lib.licenses.gpl2Only;
    platforms = lib.intersectLists lib.platforms.aarch64 lib.platforms.linux;
  };
}
