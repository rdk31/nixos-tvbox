{
  coreelecSource,
  ffmpeg,
}:

ffmpeg.overrideAttrs (old: {
  pname = "ffmpeg-amlogic";
  patches = (old.patches or [ ]) ++ [
    "${coreelecSource}/packages/multimedia/ffmpeg/patches/0001-added_upstream_mvc_patches.patch"
    "${coreelecSource}/packages/multimedia/ffmpeg/patches/0002-MKV-added-basic-block-addition-mapping-support-for-m.patch"
    "${coreelecSource}/packages/multimedia/ffmpeg/patches/0003-Add-hdr10p-raw.patch"
  ];
})
