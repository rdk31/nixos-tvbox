{
  config,
  pkgs,
  ...
}:

{
  boot.extraModulePackages = [ config.boot.kernelPackages.gpu-aml ];
  boot.kernelModules = [ "mali_kbase" ];

  hardware.firmware = [ pkgs.mali-csf-firmware ];
  hardware.firmwareCompression = "none";
  hardware.graphics.enable = true;
  services.udev.extraRules = ''
    KERNEL=="mali0", GROUP="render", MODE="0660"
    SUBSYSTEM=="drm", GROUP="video", MODE="0660"
    SUBSYSTEM=="dma_heap", GROUP="render", MODE="0660"
    KERNEL=="ion", GROUP="render", MODE="0660"
  '';
}
