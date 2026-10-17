{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hardware.amlogic.remote;
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  bluetoothFirmwareFiles = lib.mapAttrs (_target: source: {
    inherit source;
  }) cfg.bluetooth.firmwareFiles;
  infraredConfig = "/etc/${cfg.infrared.configTarget}";
  infraredRuntimeConfig = "/run/amlogic-infrared-remote.conf";
  infraredTransform = pkgs.writeText "amlogic-infrared-remote-transform" cfg.infrared.configTransform;

  modprobeLoad = module: "modprobe ${lib.escapeShellArg module}";
in
{
  options.hardware.amlogic.remote = {
    bluetooth = {
      enable = mkEnableOption "Amlogic Bluetooth controller support";

      device = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Serial device used by hciattach.";
      };

      deviceUnit = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "systemd device unit corresponding to the Bluetooth serial device.";
      };

      firmwareFiles = mkOption {
        type = types.attrsOf types.path;
        default = { };
        description = "Firmware files to install below /etc for the Bluetooth controller.";
      };

      initialSpeed = mkOption {
        type = types.ints.positive;
        default = 115200;
        description = "Initial serial speed passed to hciattach.";
      };

      protocol = mkOption {
        type = types.str;
        default = "bcm43xx";
        description = "hciattach protocol name.";
      };

      speed = mkOption {
        type = types.ints.positive;
        default = 2000000;
        description = "Controller serial speed passed to hciattach.";
      };

      powerOnBoot = mkOption {
        type = types.bool;
        default = true;
        description = "Whether Bluetooth should be powered on during boot.";
      };
    };

    infrared = {
      enable = mkEnableOption "Amlogic infrared remote support";

      configFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Amlogic amremote configuration file.";
      };

      configTarget = mkOption {
        type = types.str;
        default = "amlogic/remote.conf";
        description = "Relative path below /etc where the amremote configuration is installed.";
      };

      configTransform = mkOption {
        type = types.lines;
        default = "";
        description = "Optional sed script applied to a writable copy before loading the keymap.";
      };

      deviceTreePaths = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Device-tree paths that must exist before the infrared service runs.";
      };

      kernelModules = mkOption {
        type = types.listOf types.str;
        default = [ "meson_remote" ];
        description = "Kernel modules to load before configuring the infrared remote.";
      };

      blacklistedKernelModules = mkOption {
        type = types.listOf types.str;
        default = [ "meson_ir" ];
        description = "Conflicting kernel modules to prevent from loading.";
      };

      wantedBy = mkOption {
        type = types.listOf types.str;
        default = [ "multi-user.target" ];
        description = "systemd targets that should start the infrared service.";
      };

      before = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "systemd units that should start after the infrared service.";
      };

      after = mkOption {
        type = types.listOf types.str;
        default = [ "systemd-modules-load.service" ];
        description = "systemd units that should start before the infrared service.";
      };
    };
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !cfg.bluetooth.enable || cfg.bluetooth.device != null;
          message = "hardware.amlogic.remote.bluetooth.device must be set when Bluetooth support is enabled.";
        }
        {
          assertion = !cfg.bluetooth.enable || cfg.bluetooth.deviceUnit != null;
          message = "hardware.amlogic.remote.bluetooth.deviceUnit must be set when Bluetooth support is enabled.";
        }
        {
          assertion = !cfg.infrared.enable || cfg.infrared.configFile != null;
          message = "hardware.amlogic.remote.infrared.configFile must be set when infrared support is enabled.";
        }
      ];
    }

    (mkIf cfg.bluetooth.enable {
      hardware.bluetooth = {
        enable = true;
        powerOnBoot = cfg.bluetooth.powerOnBoot;
      };

      environment.etc = bluetoothFirmwareFiles;
      environment.systemPackages = [ pkgs.bluez ];
    })

    (mkIf (cfg.bluetooth.enable && cfg.bluetooth.device != null && cfg.bluetooth.deviceUnit != null) {
      systemd.services.amlogic-bluetooth-attach = {
        description = "Attach the Amlogic Bluetooth controller";
        # The UART must create hci0 before bluetooth.target can be reached.
        wantedBy = [ "multi-user.target" ];
        before = [ "bluetooth.service" ];
        after = [ cfg.bluetooth.deviceUnit ];
        requires = [ cfg.bluetooth.deviceUnit ];
        serviceConfig = {
          Type = "simple";
          ExecStartPre = [
            "${pkgs.util-linux}/bin/rfkill unblock bluetooth"
          ];
          ExecStart = "${lib.getExe' pkgs.bluez "hciattach"} -n -s ${toString cfg.bluetooth.initialSpeed} ${lib.escapeShellArg cfg.bluetooth.device} ${lib.escapeShellArg cfg.bluetooth.protocol} ${toString cfg.bluetooth.speed}";
          ExecStopPost = "${pkgs.util-linux}/bin/rfkill block bluetooth";
          Restart = "on-failure";
          RestartSec = 2;
        };
      };
    })

    (mkIf cfg.infrared.enable {
      boot.blacklistedKernelModules = cfg.infrared.blacklistedKernelModules;
      environment.systemPackages = [ pkgs.amremote ];
    })

    (mkIf (cfg.infrared.enable && cfg.infrared.configFile != null) {
      environment.etc."${cfg.infrared.configTarget}".source = cfg.infrared.configFile;

      systemd.services.amlogic-infrared-remote = {
        description = "Configure the Amlogic infrared remote";
        wantedBy = cfg.infrared.wantedBy;
        before = cfg.infrared.before;
        after = cfg.infrared.after;
        unitConfig.ConditionPathExists = cfg.infrared.deviceTreePaths;
        path = [
          pkgs.coreutils
          pkgs.gnused
          pkgs.kmod
        ];
        serviceConfig.Type = "oneshot";
        script = ''
          set -eu
          ${lib.concatMapStringsSep "\n" modprobeLoad cfg.infrared.kernelModules}

          cp ${lib.escapeShellArg infraredConfig} ${lib.escapeShellArg infraredRuntimeConfig}
          if [ -s ${lib.escapeShellArg infraredTransform} ]; then
            sed -i -f ${lib.escapeShellArg infraredTransform} ${lib.escapeShellArg infraredRuntimeConfig}
          fi
          ${lib.getExe' pkgs.amremote "remotecfg"} ${lib.escapeShellArg infraredRuntimeConfig}
        '';
      };
    })
  ];
}
