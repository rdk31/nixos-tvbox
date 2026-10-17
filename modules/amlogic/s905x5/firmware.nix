{
  config,
  lib,
  pkgs,
  ...
}:

let
  videoFirmware = "${config.boot.kernelPackages.media-modules-aml}/lib/firmware/video/S905X5/video_ucode.bin";
  sleepCommand = lib.getExe' pkgs.coreutils "sleep";
  teeSupplicant = lib.getExe' pkgs.opentee-amlogic "tee-supplicant";
  teePreloadFirmware = lib.getExe' pkgs.opentee-amlogic "tee_preload_fw";
  teeSetup = pkgs.writeShellScript "amlogic-tee-supplicant-setup" ''
    set -eu
    echo Y > /sys/module/firmware/parameters/dos_tee_enabled
    ln -sfnT ${pkgs.opentee-amlogic}/lib/optee_armtz/S905X5 /lib/optee_armtz
  '';
in
{
  systemd.services.amlogic-tee-supplicant = {
    description = "Amlogic OP-TEE supplicant";
    wantedBy = [ "multi-user.target" ];
    before = [ "amlogic-video-firmware.service" ];
    after = [ "systemd-modules-load.service" ];
    serviceConfig = {
      Type = "simple";
      ExecStartPre = teeSetup;
      ExecStart = teeSupplicant;
      Restart = "on-failure";
      RestartSec = 2;
    };
    environment.LD_LIBRARY_PATH = "${pkgs.opentee-amlogic}/lib";
  };

  systemd.services.amlogic-video-firmware = {
    description = "Preload Amlogic video firmware through OP-TEE";
    wantedBy = [ "multi-user.target" ];
    after = [
      "amlogic-tee-supplicant.service"
      "systemd-modules-load.service"
    ];
    requires = [ "amlogic-tee-supplicant.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "amlogic-video-firmware-start" ''
        set -eu
        if [ -e /run/amlogic-video-firmware-preloaded ]; then
          exit 0
        fi

        attempt=1
        while ! ${teePreloadFirmware} ${videoFirmware} >/dev/null 2>&1; do
          if [ "$attempt" -ge 100 ]; then
            echo "Timed out after 10 seconds waiting for tee-supplicant to preload ${videoFirmware}" >&2
            exit 1
          fi
          attempt=$((attempt + 1))
          ${sleepCommand} 0.1
        done

        touch /run/amlogic-video-firmware-preloaded
      '';
    };
    environment.LD_LIBRARY_PATH = "${pkgs.opentee-amlogic}/lib";
  };
}
