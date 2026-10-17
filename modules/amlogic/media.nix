{ config, ... }:

{
  boot.extraModulePackages = [ config.boot.kernelPackages.media-modules-aml ];
  boot.kernelModules = [
    "media_clock"
    "firmware"
    "decoder_common"
    "stream_input"
    "media_sync"
    "pts_server"
    "video_framerate_adapter"
    "amvdec_mmpeg12"
    "amvdec_mmpeg4"
    "amvdec_vc1"
    "amvdec_mh264"
    "amvdec_h264mvc"
    "amvdec_h265"
    "amvdec_h265_fb"
    "amvdec_h266"
    "amvdec_mmjpeg"
    "amvdec_mavs"
    "amvdec_avs2"
    "amvdec_avs2_fb"
    "amvdec_avs3"
    "amvdec_vp9"
    "amvdec_vp9_fb"
    "amvdec_av1"
    "amvdec_av1_fb"
  ];

  hardware.enableRedistributableFirmware = true;
  hardware.firmware = [ config.boot.kernelPackages.media-modules-aml ];
}
