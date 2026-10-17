#!/usr/bin/env bash

system=$(readlink -e "${1:?expected a NixOS system path}")
# Image builds supply an output directory; activation supplies only the system.
destination=${2:-}
generation=${system##*/}
generation=${generation%%-*}
[[ $generation =~ ^[0-9a-z]{32}$ ]]

temporary=$(mktemp -d)
cleanup() {
  if mountpoint -q "$temporary/boot"; then
    umount "$temporary/boot"
  fi
  rm -rf -- "$temporary"
}
trap cleanup EXIT

if [[ -z $destination ]]; then
  [[ $EUID -eq 0 ]]
  exec 9>/run/lock/amlogic-sd-boot.lock
  flock -x 9

  root_part=$(readlink -e "$(findmnt -nro SOURCE /)")
  root_parent=$(lsblk -dnpo PKNAME "$root_part")
  boot_part="${root_parent}p1"
  [[ $root_part == /dev/mmcblk*p2 ]]
  [[ -b $root_parent && -b $boot_part ]]
  [[ "$(lsblk -dnro LABEL "$root_part")" == NIXOS_SD ]]
  [[ "$(cat "/sys/class/block/${root_parent##*/}/device/type")" == SD ]]
  [[ "$(lsblk -dnro LABEL "$boot_part")" == NIXOS_BOOT ]]
  [[ "$(lsblk -dnro FSTYPE "$boot_part")" == vfat ]]

  destination="$temporary/boot"
  mkdir "$destination"
  mount -t vfat -o rw "$boot_part" "$destination"
fi

cmdline=$(jq -er --arg init "$system/init" '
  ."org.nixos.bootspec.v1"
  | select(.system == "aarch64-linux" and .init == $init)
  | (.kernelParams + ["rw", "init=" + .init]) | join(" ")
' "$system/boot.json")
bootargs=$(printf '%s' "$cmdline" | jq -Rrs '@sh')
printf '%s\n' "$cmdline" >"$temporary/cmdline.txt"
cat >"$temporary/cfgload.src" <<EOF_SCRIPT
setenv bootargs $bootargs
if test "\${loadaddr_kernel}" != ""; then
  setenv loadaddr_kernel "0x02000000"
  setenv loadaddr "\${loadaddr_kernel}"
fi
if fatload \${device} \${devnr}:\${partnr} \${loadaddr} nixos/$generation/kernel.img; then
  if fatload \${device} \${devnr}:\${partnr} \${dtb_mem_addr} nixos/$generation/dtb.img; then
    bootm \${loadaddr}
  fi
fi
EOF_SCRIPT
cat >"$temporary/aml_autoscript.src" <<'EOF_SCRIPT'
if mmcinfo; then
  if fatload mmc 0:1 ${loadaddr} cfgload; then
    setenv device mmc
    setenv devnr 0
    setenv partnr 1
    source ${loadaddr}
  fi
fi
EOF_SCRIPT
for script in cfgload aml_autoscript; do
  mkimage -A arm64 -O linux -T script -C none \
    -d "$temporary/$script.src" "$temporary/$script"
done

# Keep the selected payload until its replacement has been fully written.
previous=""
if [[ -f "$destination/cfgload" ]]; then
  previous=$(LC_ALL=C grep -aoE 'nixos/[0-9a-z]{32}/kernel.img' "$destination/cfgload" || true)
  previous=${previous#nixos/}
  previous=${previous%/kernel.img}
  [[ -z $previous || $previous =~ ^[0-9a-z]{32}$ ]]
fi
if [[ $generation != "$previous" ]]; then
  for directory in "$destination/nixos/"*; do
    name=${directory##*/}
    if [[ $name =~ ^[0-9a-z]{32}$ && $name != "$previous" && $name != "$generation" ]]; then
      rm -rf -- "$directory"
    fi
  done
  mkdir -p "$destination/nixos/$generation"
  cp "$system/amlogic-boot/"{kernel.img,dtb.img} "$destination/nixos/$generation/"
  sync -f "$destination"
fi

# Replace the selector last. FAT is still not power-loss atomic.
for artifact in aml_autoscript cmdline.txt cfgload; do
  install -m 0644 "$temporary/$artifact" "$destination/.$artifact.new"
  sync -f "$destination"
  mv -f "$destination/.$artifact.new" "$destination/$artifact"
  sync -f "$destination"
done
