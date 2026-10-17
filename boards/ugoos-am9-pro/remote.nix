{ pkgs, ... }:

{
  hardware.amlogic.remote = {
    bluetooth = {
      enable = true;
      device = "/dev/ttyS1";
      deviceUnit = "dev-ttyS1.device";
      firmwareFiles."firmware/BCM4362A2.hcd" =
        "${pkgs.brcm-firmware-amlogic}/lib/firmware/brcm/BCM4362A2.hcd";
    };

    infrared = {
      enable = true;
      configFile = ./ugoos-ur02-remote.conf;
      deviceTreePaths = [
        "/proc/device-tree/meson-ir/compatible"
        "/proc/device-tree/meson-remote/compatible"
      ];
      wantedBy = [ "graphical.target" ];
      configTransform = ''
        s/ 15[^0-9]*$/ 1/
        s/ 63[^0-9]*$/ 90/
        s/ 97[^0-9]*$/ 28/
        s/ 102[^0-9]*$/ 172/
        s/ 125[^0-9]*$/ 46/
        s/ 128[^0-9]*$/ 45/
        s/ 139[^0-9]*$/ 46/
        s/ 142[^0-9]*$/ 116/
        s/ 143[^0-9]*$/ 116/
        s/ 158[^0-9]*$/ 1/
        s/ 183[^0-9]*$/ 59/
        s/ 184[^0-9]*$/ 399/
        s/ 185[^0-9]*$/ 400/
        s/ 186[^0-9]*$/ 60/
        s/ 232[^0-9]*$/ 28/
        s/ 240[^0-9]*$/ 164/
        s/ 241[^0-9]*$/ 163/
        s/ 242[^0-9]*$/ 165/
        s/ 244[^0-9]*$/ 208/
        s/ 245[^0-9]*$/ 168/
        s/ 264[^0-9]*$/ 63/
        s/ 704[^0-9]*$/ 116/
      '';
    };
  };
}
