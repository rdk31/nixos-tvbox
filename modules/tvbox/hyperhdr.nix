{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixos-tvbox.hyperhdr;
in
{
  options.nixos-tvbox.hyperhdr = {
    enable = lib.mkEnableOption "HyperHDR Amlogic ambient-light capture";
    openFirewall = lib.mkEnableOption "opening TCP ports 8090 and 8092 for the HyperHDR web interface";
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.systemd.services.amlogic-video-firmware.enable or false;
        message = "nixos-tvbox.hyperhdr requires Amlogic video firmware support; import nixosModules.amlogic-s905x5 or nixosModules.ugoos-am9-pro.";
      }
    ];

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [
      8090
      8092
    ];

    # Keep the compressed display frame and add a quarter-resolution linear
    # companion for amvideocap. Mode 0 is not capturable, mode 1 replaces the
    # display path with a full-resolution 8-bit surface, and mode 16 produced
    # corrupt capture data on the AM9 Pro.
    boot.extraModprobeConfig = ''
      options amvdec_h265 double_write_mode=3
    '';

    users.groups.hyperhdr = { };
    users.users.hyperhdr = {
      isSystemUser = true;
      group = "hyperhdr";
      home = "/var/lib/hyperhdr";
      extraGroups = [ "video" ];
    };
    systemd.services.hyperhdr = {
      description = "HyperHDR Amlogic ambient-light capture";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "amlogic-video-firmware.service"
      ];
      requires = [ "amlogic-video-firmware.service" ];
      serviceConfig = {
        User = "hyperhdr";
        Group = "hyperhdr";
        SupplementaryGroups = [ "video" ];
        StateDirectory = "hyperhdr";
        WorkingDirectory = "/var/lib/hyperhdr";
        ExecStart = "${lib.getExe pkgs.hyperhdr-amlogic} --userdata /var/lib/hyperhdr";
        Restart = "on-failure";
        RestartSec = 3;
        TimeoutStopSec = 10;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        UMask = "0077";
      };
    };
  };
}
