# nixos-tvbox

NixOS modules for TV boxes with Kodi, hardware video decoding, Dolby Vision,
Moonlight game streaming, and HyperHDR ambient lighting.

## Configure your box

The example below targets the Ugoos AM9 Pro (Amlogic S905X5-J), which boots
from an SD card using stock Ugoos firmware. Add this configuration to your
homelab flake:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-tvbox.url = "github:rdk31/nixos-tvbox";
  };

  outputs = { self, nixpkgs, nixos-tvbox, ... }: {
    nixosConfigurations.tvbox = nixpkgs.lib.nixosSystem {
      modules = [
        nixos-tvbox.nixosModules.ugoos-am9-pro
        {
          networking.hostName = "tvbox";
          services.openssh = {
            enable = true;
            settings = {
              PasswordAuthentication = false;
              PermitRootLogin = "no";
            };
          };
          users.users.tvbox = {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            openssh.authorizedKeys.keys = [
              "ssh-ed25519 REPLACE_WITH_YOUR_PUBLIC_KEY"
            ];
          };
          security.sudo.wheelNeedsPassword = false;
          nix.settings.trusted-users = [ "root" "tvbox" ];
        }
      ];
    };

    packages.aarch64-linux.tvbox-image =
      (self.nixosConfigurations.tvbox.extendModules {
        modules = [ nixos-tvbox.nixosModules.ugoos-am9-pro-image ];
      }).config.system.build.sdImage;
  };
}
```

The `ugoos-am9-pro` module includes the TV services and S905X5 hardware profile.
This configuration requires Ugoos firmware older than 2.2.0.
For another S905X5 board, `nixosModules.amlogic-s905x5` provides that shared
profile; supply the board's boot, storage, and remote configuration separately.
The services-only `nixosModules.nixos-tvbox` requires a hardware module that
provides the Amlogic video-firmware service.

## Build and boot your SD image

Build your configured image on an `aarch64-linux` NixOS builder, then identify
the SD card you will flash:

```console
nix build .#tvbox-image
lsblk -o NAME,SIZE,MODEL,TRAN,RM,MOUNTPOINTS
```

Unmount the target card's partitions. Replace `/dev/sdX` with the whole
SD-card device; this erases its contents.

```console
zstdcat result/sd-image/nixos-tvbox-ugoos-am9-pro.img.zst \
  | sudo dd of=/dev/sdX bs=16M conv=fsync status=progress
```

Connect the box to Ethernet, insert the card, and power on while holding the
Ugoos recovery button. Kodi starts on the TV. Find the box's IP address in
your router, then connect using the SSH key you configured:

```console
ssh tvbox@BOX_IP
```

## Update

Deploy changes without reflashing the card:

```console
nixos-rebuild switch --flake .#tvbox --target-host tvbox@BOX_IP --sudo
```

Reboot the box after a kernel update.

## Optional features

Add the settings you want to the inline configuration above, then rebuild:

### Kodi add-ons

- **Jellyfin** — browse and play media from your Jellyfin server.
- **YouTube** — watch YouTube in Kodi.
- **External frontends** — launch Moonlight profiles from Kodi; included
  automatically when Moonlight is enabled.

```nix
nixos-tvbox.kodi.jellyfin.enable = true;
nixos-tvbox.kodi.youtube.enable = true;
```

### Dolby Vision

Enjoy Dolby Vision HDR playback in Kodi with compatible movies and a
Dolby Vision-capable TV:

```nix
hardware.amlogic.dolbyVision.enable = true;
```

Rebuild and reboot after enabling it to load Dolby Vision support.

### HyperHDR ambient lighting

Sync LED strips behind your TV with the colors in Kodi movies and Moonlight
games. HyperHDR captures video directly on the box, without an HDMI capture
card. When enabled in HyperHDR, HDR tone mapping automatically follows
HDR/SDR playback.

```nix
nixos-tvbox.hyperhdr = {
  enable = true;
  openFirewall = true;
};
```

Open `http://BOX_IP:8090` to configure capture and your LEDs. `openFirewall`
opens TCP ports 8090 (HTTP) and 8092 (HTTPS); it defaults to `false`. If you
change these ports in HyperHDR, update `networking.firewall.allowedTCPPorts`
to match.

### Moonlight game streaming

Run Sunshine on your gaming PC. Add this configuration, replacing
`192.168.1.10` with the PC's IP address and `Steam` with its Sunshine app name:

```nix
nixos-tvbox.moonlight = {
  enable = true;
  profiles.steam = {
    host = "192.168.1.10";
    app = "Steam";
  };
};
```

Rebuild, then pair from the TV box:

```console
sudo -u kodi env HOME=/var/lib/kodi \
  moonlight pair -keydir /var/lib/kodi/.cache/moonlight 192.168.1.10
```

Enter the PIN in Sunshine and allow **Launch applications** if you use
per-client permissions. In Kodi, open **Programs → External frontends** and
select **Moonlight — Steam**. Press Play+Back+LeftShoulder+RightShoulder to
return to Kodi.

## License

[MIT](LICENSE).
