{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.nixos-tvbox.moonlight;
  singleLine = lib.types.strMatching ".+";
  profileType = lib.types.submodule {
    options = {
      label = lib.mkOption {
        type = singleLine;
        default = "Moonlight";
        description = "Label displayed by the Kodi frontend launcher.";
      };
      host = lib.mkOption {
        type = lib.types.nullOr (lib.types.strMatching "[^[:space:]]+");
        default = null;
        description = "Sunshine host name or address; null enables automatic discovery.";
      };
      app = lib.mkOption {
        type = singleLine;
        default = "Steam";
        description = "Sunshine application to launch.";
      };
      width = lib.mkOption {
        type = lib.types.ints.positive;
        default = 1920;
        description = "Requested stream width.";
      };
      height = lib.mkOption {
        type = lib.types.ints.positive;
        default = 1080;
        description = "Requested stream height.";
      };
      fps = lib.mkOption {
        type = lib.types.ints.positive;
        default = 60;
        description = "Requested stream refresh rate.";
      };
      bitrate = lib.mkOption {
        type = lib.types.int;
        default = -1;
        description = "Stream bitrate in Kbps, or -1 for Moonlight's default.";
      };
      packetSize = lib.mkOption {
        type = lib.types.ints.positive;
        default = 1392;
        description = "Maximum streaming packet size.";
      };
      codec = lib.mkOption {
        type = lib.types.enum [
          "auto"
          "h264"
          "h265"
          "hevc"
        ];
        default = "h264";
        description = "Requested video codec; H.264 is the reliable default for the Amlogic backend.";
      };
      audioDevice = lib.mkOption {
        type = singleLine;
        default = "sysdefault";
        description = "ALSA output device.";
      };
      surround = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.enum [
            "5.1"
            "7.1"
          ]
        );
        default = null;
        description = "Optional surround-sound layout.";
      };
      quitAppAfter = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Ask Sunshine to stop the remote application when the stream ends.";
      };
    };
  };

  profileConfig =
    name: profile:
    pkgs.writeText "moonlight-${name}.conf" ''
      width = ${toString profile.width}
      height = ${toString profile.height}
      fps = ${toString profile.fps}
      bitrate = ${toString profile.bitrate}
      packetsize = ${toString profile.packetSize}
      codec = ${profile.codec}
      app = ${profile.app}
      platform = aml
      audio = ${profile.audioDevice}
      mapping = ${cfg.package}/share/moonlight/gamecontrollerdb.txt
      remote = no
      quitappafter = ${if profile.quitAppAfter then "true" else "false"}
      keydir = /var/lib/kodi/.cache/moonlight
      ${lib.optionalString (profile.surround != null) "surround = ${profile.surround}"}
    '';

  launchers = lib.mapAttrs (name: profile: {
    inherit (profile) label;
    checkCommand = [
      (lib.getExe cfg.package)
      "list"
      "-config"
      (profileConfig name profile)
    ]
    ++ lib.optional (profile.host != null) profile.host;
    checkTimeout = 10;
    command = [
      (lib.getExe pkgs.amlogic-drm-session)
      (toString profile.width)
      (toString profile.height)
      (toString profile.fps)
      "--"
      (lib.getExe cfg.package)
      "stream"
      "-config"
      (profileConfig name profile)
    ]
    ++ lib.optional (profile.host != null) profile.host;
  }) cfg.profiles;
in
{
  imports = [ ./frontend.nix ];

  options.nixos-tvbox.moonlight = {
    enable = lib.mkEnableOption "Moonlight game streaming through the Amlogic video decoder";

    package = lib.mkPackageOption pkgs "moonlight-embedded-amlogic" { };

    profiles = lib.mkOption {
      type = lib.types.attrsOf profileType;
      default = {
        steam.label = "Moonlight — Steam";
      };
      description = "Moonlight streaming profiles offered in Kodi.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.nixos-tvbox.kodi.enable;
        message = "nixos-tvbox.moonlight requires nixos-tvbox.kodi.enable.";
      }
      {
        assertion = cfg.profiles != { };
        message = "nixos-tvbox.moonlight.profiles must contain at least one profile.";
      }
      {
        assertion = lib.all (profile: profile.bitrate == -1 || profile.bitrate > 0) (
          builtins.attrValues cfg.profiles
        );
        message = "Moonlight profile bitrates must be -1 or positive.";
      }
      {
        assertion = lib.all (profile: lib.mod profile.packetSize 16 == 0) (
          builtins.attrValues cfg.profiles
        );
        message = "Moonlight profile packet sizes must be multiples of 16.";
      }
    ];

    nixos-tvbox.frontend.launchers = launchers;

    environment.systemPackages = [ cfg.package ];

    services.udev.extraRules = ''
      KERNEL=="amvideo", GROUP="video", MODE="0660"
      KERNEL=="video10", GROUP="video", MODE="0660"
    '';

    systemd.tmpfiles.rules = [
      "d /var/lib/kodi/.cache 0750 kodi kodi -"
      "d /var/lib/kodi/.cache/moonlight 0750 kodi kodi -"
    ];
  };
}
