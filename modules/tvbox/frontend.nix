{
  config,
  lib,
  ...
}:

let
  cfg = config.nixos-tvbox.frontend;
  launcherType = lib.types.submodule {
    options = {
      label = lib.mkOption {
        type = lib.types.strMatching ".+";
        description = "Human-readable label shown in Kodi.";
      };
      command = lib.mkOption {
        type = lib.types.nonEmptyListOf (lib.types.coercedTo lib.types.package toString lib.types.str);
        description = "Command and arguments executed after Kodi exits.";
      };
      checkCommand = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.nonEmptyListOf (lib.types.coercedTo lib.types.package toString lib.types.str)
        );
        default = null;
        description = "Optional command that must succeed before Kodi exits.";
      };
      checkTimeout = lib.mkOption {
        type = lib.types.ints.positive;
        default = 10;
        description = "Maximum number of seconds allowed for the preflight command.";
      };
    };
  };
in
{
  options.nixos-tvbox.frontend.launchers = lib.mkOption {
    type = lib.types.attrsOf launcherType;
    default = { };
    internal = true;
    description = "External fullscreen frontends available to the Kodi session supervisor.";
  };

  config = lib.mkIf (cfg.launchers != { }) {
    # Seed safe CEC handoff defaults without overwriting user-customized settings.
    systemd.tmpfiles.rules = [
      "d /var/lib/kodi/.kodi 0750 kodi kodi -"
      "d /var/lib/kodi/.kodi/userdata 0750 kodi kodi -"
      "d /var/lib/kodi/.kodi/userdata/peripheral_data 0750 kodi kodi -"
      "C /var/lib/kodi/.kodi/userdata/peripheral_data/cec_CEC_Adapter.xml 0640 kodi kodi - ${./frontend-cec.xml}"
    ];

    environment.etc."nixos-tvbox/frontend-launchers.json".text = builtins.toJSON (
      lib.mapAttrsToList (id: launcher: {
        inherit id;
        inherit (launcher) label checkCommand checkTimeout;
      }) cfg.launchers
    );
  };
}
