inputs: final: _prev:

{
  ffmpeg-amlogic = final.callPackage ../pkgs/ffmpeg-amlogic {
    coreelecSource = inputs.coreelec;
  };
  kodi-amlogic = final.callPackage ../pkgs/kodi-amlogic {
    src = inputs.coreelec-kodi;
    inherit (final) libamcodec libmali;
    coreelecSource = inputs.coreelec;
    ffmpeg = final.ffmpeg-amlogic;
    obuUtil = final.obu-util;
  };
  kodi-addons = final.callPackage ../pkgs/kodi-addons {
    inherit (final.kodi-amlogic) kodi;
  };
}
