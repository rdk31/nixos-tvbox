{
  fetchurl,

  coreelecSource,
  libbluray,
}:

libbluray.overrideAttrs (old: {
  version = "1.5.0";
  src = fetchurl {
    url = "https://download.videolan.org/pub/videolan/libbluray/1.5.0/libbluray-1.5.0.tar.xz";
    hash = "sha256-9nZAjpGl0yGr+LjU39rjYgXCl9q1xUw+xRljkCX0dKI=";
  };
  patches = (old.patches or [ ]) ++ [
    "${coreelecSource}/packages/multimedia/libbluray/patches/all-001-forward-1.0.2.patch"
    "${coreelecSource}/packages/multimedia/libbluray/patches/all-002-add-3D-subtitle-depth-plane-info.patch"
    "${coreelecSource}/packages/multimedia/libbluray/patches/libbluray-01-seek-limit-seek-position-to-title-duration.patch"
    "${coreelecSource}/packages/multimedia/libbluray/patches/libbluray-02-seek-fix-cut-off-starting-packet-after-seek.patch"
    "${coreelecSource}/packages/multimedia/libbluray/patches/libbluray-03-m2ts_filter-clear-the-payload-unit-start-flag-of-a-wiped-packet.patch"
    "${coreelecSource}/packages/multimedia/libbluray/patches/libbluray-04-seek-start-at-dual-layer-video-entry-point.patch"
  ];
})
