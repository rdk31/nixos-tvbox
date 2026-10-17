{
  coreelecSource,
  ffmpeg_9,
}:

# Keep the FFmpeg major version aligned with the pinned CoreELEC Kodi fork.
ffmpeg_9.overrideAttrs (old: {
  pname = "ffmpeg-amlogic";
  patches = (old.patches or [ ]) ++ [
    "${coreelecSource}/packages/multimedia/ffmpeg/patches/0001-added_upstream_mvc_patches.patch"
    "${coreelecSource}/packages/multimedia/ffmpeg/patches/0002-MKV-added-basic-block-addition-mapping-support-for-m.patch"
    "${coreelecSource}/packages/multimedia/ffmpeg/patches/0003-avcodec-dca_core-export-bits_per_raw_sample-from-header.patch"
    "${coreelecSource}/packages/multimedia/ffmpeg/patches/008-ffmpeg-all-pgssubdec-use-caller-colorspace.patch"
    "${coreelecSource}/packages/multimedia/ffmpeg/patches/009-ffmpeg-all-pgssubdec-ignore-lone-end-segment.patch"
  ];
})
