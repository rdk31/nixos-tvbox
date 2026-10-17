{
  fetchgit,

  coreelecSource,
  libbluray,
}:

libbluray.overrideAttrs (old: {
  version = "1.4.0";
  src = fetchgit {
    url = "https://code.videolan.org/videolan/libbluray.git";
    rev = "9f07fbb2077be7a40b062bcf2463a9941c2a3b13";
    hash = "sha256-z4MHE2+p5Mtr+IdujcitjlM/K7iXzwcrW/3rrfJxixU=";
    fetchSubmodules = true;
  };
  patches = (old.patches or [ ]) ++ [
    "${coreelecSource}/packages/multimedia/libbluray/patches/all-001-forward-1.0.2.patch"
    "${coreelecSource}/packages/multimedia/libbluray/patches/all-002-add-3D-subtitle-depth-plane-info.patch"
    "${coreelecSource}/packages/multimedia/libbluray/patches/libbluray-01-seek-limit-seek-position-to-title-duration.patch"
    "${coreelecSource}/packages/multimedia/libbluray/patches/libbluray-02-seek-fix-cut-off-starting-packet-after-seek.patch"
  ];
})
