{
  config,
  lib,
  pkgs,
  ...
}:

let
  kernel = config.boot.kernelPackages.kernel;
  kernelImage = "${kernel}/${config.system.boot.loader.kernelFile}";
  initrd = "${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile}";
  dtb = "${kernel}/dtbs/s6_s905x5_ugoos_am9_pro.dtb";
  installer = pkgs.writeShellApplication {
    name = "amlogic-install-boot";
    inheritPath = false;
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      jq
      ubootTools
      util-linux
    ];
    text = builtins.readFile ./install-boot.sh;
  };
  payload =
    pkgs.runCommand "ugoos-am9-pro-boot-payload"
      {
        nativeBuildInputs = [
          pkgs.android-tools
          pkgs.dtc
          pkgs.lzop
        ];
      }
      ''
        mkdir -p $out
        lzop -9 -c ${kernelImage} > Image.lzo
        mkbootimg --header_version 0 --base 0x0 --kernel_offset 0x02000000 \
          --kernel Image.lzo --ramdisk ${initrd} --output $out/kernel.img
        cp ${dtb} $out/dtb.img

        mkdir unpacked
        unpack_bootimg --boot_img $out/kernel.img --out unpacked
        cmp Image.lzo unpacked/kernel
        cmp ${initrd} unpacked/ramdisk
        lzop -t unpacked/kernel
        test "$(fdtget -t s $out/dtb.img / model)" = "Ugoos AM9 Pro"
        test "$(fdtget -t s $out/dtb.img / coreelec-dt-id)" = "s6_s905x5_ugoos_am9_pro"
      '';
in
{
  boot.loader.external = {
    enable = true;
    installHook = "${installer}/bin/amlogic-install-boot";
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
    };
    "/boot/firmware" = {
      device = "/dev/disk/by-label/NIXOS_BOOT";
      fsType = "vfat";
      # sd-image.nix also defines these; defaults avoid duplicating fstab options.
      options = lib.mkDefault [
        "nofail"
        "noauto"
      ];
    };
  };

  # The payload belongs to the system closure, so ordinary deployment copies
  # everything needed. It must not refer back to the toplevel (a build cycle).
  system.systemBuilderCommands = ''
    ln -s ${payload} $out/amlogic-boot
  '';
  system.build.amlogicBootArtifacts =
    pkgs.runCommand "ugoos-am9-pro-image-boot-artifacts"
      {
        nativeBuildInputs = [ installer ];
      }
      ''
        amlogic-install-boot ${config.system.build.toplevel} $out
      '';
}
