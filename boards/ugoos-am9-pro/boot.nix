{ lib, ... }:

{
  boot.kernelParams = [
    "console=ttyAML0,115200n8"
    "console=tty0"
    "no_console_suspend"
    "rootwait"
    "vout=2160p60hz,dis"
    "frac_rate_policy=0"
    "hdr_policy=1"
  ];

  boot.initrd = {
    includeDefaultModules = false;
    availableKernelModules = lib.mkForce [ ];
    compressor = "zstd";
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="video4linux", GROUP="video", MODE="0660"
    KERNEL=="amvideo*", GROUP="video", MODE="0660"
    KERNEL=="amstream*", GROUP="video", MODE="0660"
    KERNEL=="amvecm", GROUP="video", MODE="0660"
    KERNEL=="amhdmitx*", GROUP="video", MODE="0660"
    KERNEL=="cec*", GROUP="video", MODE="0660"
  '';
}
