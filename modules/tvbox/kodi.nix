{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.nixos-tvbox.kodi;
  frontendCfg = config.nixos-tvbox.frontend;
  selectedKodiAddons =
    lib.optionals cfg.jellyfin.enable [ pkgs.kodi-amlogic.kodi.packages.jellyfin ]
    ++ lib.optionals cfg.youtube.enable [ pkgs.kodi-addons.youtube ]
    ++ lib.optionals (frontendCfg.launchers != { }) [ pkgs.kodi-addons.frontend-launcher ];
  kodi = pkgs.kodi-amlogic.kodi.withPackages (_: selectedKodiAddons);
  kodiHome = "/var/lib/kodi";
  kodiWritableSysfs = [
    "/sys/class/amdolby_vision/debug"
    "/sys/class/amdolby_vision/dv_mode"
    "/sys/class/amvecm/brightness1"
    "/sys/class/amvecm/contrast1"
    "/sys/class/amvecm/enable_hdr10plus"
    "/sys/class/graphics/fb0/blank"
    "/sys/class/graphics/fb1/blank"
    "/sys/class/tsync/enable"
    "/sys/class/vfm/map"
    "/sys/class/video/axis"
    "/sys/class/video/blackout_policy"
    "/sys/class/video/crop"
    "/sys/class/video/disable_video"
    "/sys/class/video/freerun_mode"
    "/sys/class/video/saturation"
    "/sys/class/video/screen_mode"
    "/sys/class/video/zoom"
    "/sys/module/aml_media/parameters/dolby_vision_enable"
    "/sys/module/aml_media/parameters/dolby_vision_ll_policy"
    "/sys/module/aml_media/parameters/dolby_vision_policy"
    "/sys/module/aml_media/parameters/hdr_mode"
    "/sys/module/aml_media/parameters/hdr_policy"
    "/sys/module/aml_media/parameters/nr2_en"
    "/sys/module/aml_media/parameters/sdr_mode"
  ];
  prepareAmlogicAccess = pkgs.writeShellScript "prepare-amlogic-kodi-access" ''
    for path in ${lib.escapeShellArgs kodiWritableSysfs}; do
      if [[ -e "$path" ]]; then
        ${pkgs.coreutils}/bin/chgrp video "$path"
        ${pkgs.coreutils}/bin/chmod g+w "$path"
      fi
    done
  '';
  frontendCases = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (id: launcher: ''
      ${lib.escapeShellArg id})
        echo "Starting external frontend ${lib.escapeShellArg id}"
        ${lib.escapeShellArgs launcher.command} || true
        ;;
    '') frontendCfg.launchers
  );
  kodiSession = pkgs.writeShellScript "kodi-tvbox-session" ''
    set -u
    request=/run/tvbox-frontend/request
    video_crop=""

    # The decoder restores its crop on close. Also restore it if Kodi crashes
    # or the session stops, before another frontend uses the global video plane.
    restore_video_crop() {
      if [[ -n "$video_crop" && -w /sys/class/video/crop ]]; then
        printf '%s\n' "$video_crop" > /sys/class/video/crop || true
      fi
    }
    trap restore_video_crop EXIT
    trap 'exit 143' TERM
    trap 'exit 130' INT

    while true; do
      ${pkgs.coreutils}/bin/rm -f "$request"
      if [[ -r /sys/class/video/crop && -w /sys/class/video/crop ]]; then
        video_crop="$(< /sys/class/video/crop)"
      fi
      ${lib.getExe kodi} --standalone || true
      restore_video_crop
      video_crop=""

      launcher=""
      if [[ -s "$request" ]]; then
        IFS= read -r launcher < "$request" || true
        ${pkgs.coreutils}/bin/rm -f "$request"
      fi

      case "$launcher" in
        ${frontendCases}
        "") ;;
        *) echo "Ignoring unknown external frontend: $launcher" >&2 ;;
      esac

      ${pkgs.coreutils}/bin/sleep 1
    done
  '';
in
{
  imports = [ ./frontend.nix ];

  options.nixos-tvbox.kodi = {
    enable = lib.mkEnableOption "the Kodi TV interface" // {
      default = true;
    };

    jellyfin.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Include and configure the Jellyfin for Kodi add-on.";
    };

    youtube.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Include the YouTube for Kodi add-on.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.systemd.services.amlogic-video-firmware.enable or false;
        message = "nixos-tvbox.kodi requires Amlogic video firmware support; import nixosModules.amlogic-s905x5 or nixosModules.ugoos-am9-pro.";
      }
    ];

    # The externally supplied libamcodec enables its normal ioctl path only when
    # os-release advertises CoreELEC compatibility. Keep the real NixOS ID.
    system.nixos.extraOSReleaseArgs.LIBAMCODEC_COMPAT_ID = "coreelec";

    users.users.kodi = {
      isSystemUser = true;
      group = "kodi";
      home = kodiHome;
      createHome = true;
      extraGroups = [
        "audio"
        "input"
        "render"
        "video"
      ];
    };
    users.groups.kodi = { };

    environment.systemPackages = [ kodi ];

    # CoreELEC's patched Kodi controls the Amlogic video pipeline through these
    # sysfs attributes. Give only the dedicated video group write access instead
    # of running the entire media frontend as root.
    systemd.services.amlogic-kodi-access = {
      description = "Grant Kodi access to Amlogic video controls";
      before = [ "kodi.service" ];
      after = [
        "systemd-modules-load.service"
        "systemd-udev-settle.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = prepareAmlogicAccess;
      };
    };

    systemd.services.kodi = {
      description = "Kodi fullscreen TV interface";
      wantedBy = [ "graphical.target" ];
      after = [
        "amlogic-infrared-remote.service"
        "amlogic-video-firmware.service"
        "network-online.target"
        "systemd-modules-load.service"
        "systemd-udev-settle.service"
      ];
      requires = [
        "amlogic-kodi-access.service"
        "amlogic-video-firmware.service"
      ];
      wants = [
        "network-online.target"
        "systemd-udev-settle.service"
      ];
      conflicts = [ "getty@tty1.service" ];
      serviceConfig = {
        User = "kodi";
        Group = "kodi";
        WorkingDirectory = kodiHome;
        SupplementaryGroups = [
          "audio"
          "input"
          "render"
          "video"
        ];
        TTYPath = "/dev/tty1";
        TTYReset = true;
        TTYVHangup = true;
        StandardInput = "tty";
        StandardOutput = "journal";
        StandardError = "journal";
        Restart = "always";
        RestartSec = 2;
        SuccessExitStatus = [ 143 ];
        UMask = "0002";
        RuntimeDirectory = "tvbox-frontend";
        RuntimeDirectoryMode = "0750";
      };
      environment = {
        KODI_AE_SINK = "ALSA";
      };
      script = ''
        exec ${kodiSession}
      '';
    };

    # tty1 is owned by the fullscreen appliance. Mask its getty so activating a
    # new configuration cannot race Kodi for the console.
    systemd.services."autovt@tty1".enable = false;
    systemd.services."getty@tty1".enable = false;

    systemd.tmpfiles.rules = [
      "d ${kodiHome} 0750 kodi kodi -"
    ];

    systemd.defaultUnit = "graphical.target";
  };
}
