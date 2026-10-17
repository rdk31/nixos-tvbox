inputs: final: _prev:

{
  alsa-lib-amlogic = final.callPackage ../pkgs/alsa-lib-amlogic {
    coreelecSource = inputs.coreelec;
  };
  amlogic-drm-session = final.callPackage ../pkgs/amlogic-drm-session { };
  hyperhdr-amlogic = final.callPackage ../pkgs/hyperhdr-amlogic { };
  moonlight-embedded-amlogic = final.callPackage ../pkgs/moonlight-embedded-amlogic { };
  amremote = final.callPackage ../pkgs/amremote {
    src = inputs.coreelec-amremote;
  };
  brcm-firmware-amlogic = final.callPackage ../pkgs/brcm-firmware-amlogic {
    src = inputs.coreelec-brcm-firmware;
  };
  libamcodec = final.callPackage ../pkgs/libamcodec { };
  libmali = final.callPackage ../pkgs/libmali {
    src = inputs.coreelec-libmali;
  };
  mali-csf-firmware = final.callPackage ../pkgs/mali-csf-firmware {
    coreelecSource = inputs.coreelec;
  };
  obu-util = final.callPackage ../pkgs/obu-util {
    coreelecSource = inputs.coreelec;
  };
  opentee-amlogic = final.callPackage ../pkgs/opentee-amlogic {
    coreelecSource = inputs.coreelec;
  };
}
