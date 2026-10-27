{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:

{
  imports = [
    "${modulesPath}/installer/sd-card/sd-image.nix"
  ];

  sdImage = {
    expandOnBoot = true;
    firmwarePartitionName = "NIXOS_BOOT";
    firmwareSize = 256;
    rootVolumeLabel = "NIXOS_SD";
    compressImage = true;
    populateRootCommands = "";
    populateFirmwareCommands = ''
      cp -r ${config.system.build.amlogicBootArtifacts}/. firmware/
    '';
    postBuildCommands = ''
      # The generic NixOS image marks the root partition active for extlinux.
      # Stock Amlogic removable-media boot expects the FAT boot partition.
      sfdisk --part-type "$img" 1 c
      sfdisk --activate "$img" 1
      sfdisk --verify "$img"
      sfdisk --list "$img"
    '';
  };

  # The generic sd-image unit mistakes the MMC device minor for its partition
  # number (mmcblk1p2 is minor 98). Keep the unit, but use lsblk's PARTN and a
  # dedicated success marker so a failed resize is retried on the next boot.
  systemd.services.expand-root-partition = {
    path = [
      pkgs.util-linux
      pkgs.e2fsprogs
    ];
    unitConfig.ConditionPathExists = lib.mkForce "!/var/lib/nixos-tvbox/root-expanded";
    script = lib.mkForce ''
      rootPart=$(findmnt -n -o SOURCE /)
      bootDevice=$(lsblk -npo PKNAME "$rootPart")
      partNum=$(lsblk -npo PARTN "$rootPart")

      test -b "$rootPart"
      test -b "$bootDevice"
      test -n "$partNum"

      echo ",+," | sfdisk -N "$partNum" --no-reread "$bootDevice"
      partx --update --nr "$partNum" "$bootDevice"
      resize2fs "$rootPart"

      install -d /var/lib/nixos-tvbox
      touch /var/lib/nixos-tvbox/root-expanded
    '';
  };

  image.baseName = lib.mkDefault "nixos-tvbox-ugoos-am9-pro";
}
