{
  lib,
  stdenvNoCC,
  fetchurl,

  gawk,
  kmod,
  kernel,
}:

stdenvNoCC.mkDerivation {
  pname = "dovi-module-external";
  version = kernel.modDirVersion;
  src = fetchurl {
    url = "https://discourse.coreelec.org/uploads/short-url/wJROeCGU0FOTRm8FsZ0MoO9ZF5G.ko";
    hash = "sha256-9sJmWaJVRHaFzqyUQeOZyZmx+unGQ1xI1w4UoU3X+Pc=";
  };
  dontConfigure = true;
  dontBuild = true;
  dontUnpack = true;
  nativeBuildInputs = [
    gawk
    kmod
  ];

  installPhase = ''
    module=$src

    vermagic="$(modinfo -F vermagic "$module")"
    abi_flags="''${vermagic#* }"
    if [ "$abi_flags" != "SMP preempt mod_unload modversions aarch64" ]; then
      echo "dovi.ko has unsupported ABI flags: '$abi_flags'" >&2
      exit 1
    fi

    module_name="$(modinfo -F name "$module")"
    if [ "$module_name" != "dovi_gen_5_15_2026" ]; then
      echo "unexpected Dolby Vision module name: '$module_name'" >&2
      exit 1
    fi

    kernel_build=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build
    if ! grep -qx 'CONFIG_AMLOGIC_BGKI_DEBUG_MISC=y' "$kernel_build/.config"; then
      echo "the kernel is not configured to accept the vendor module's known CRC differences" >&2
      exit 1
    fi

    mismatches=""
    while read -r module_crc symbol; do
      kernel_crc="$(awk -v symbol="$symbol" '$2 == symbol { print $1; exit }' \
        "$kernel_build/Module.symvers")"
      if [ -z "$kernel_crc" ]; then
        echo "dovi.ko imports missing kernel symbol '$symbol'" >&2
        exit 1
      fi
      if [ "$module_crc" != "$kernel_crc" ]; then
        mismatches="$mismatches $symbol"
      fi
    done < <(modprobe --dump-modversions "$module")

    if [ "$mismatches" != " module_layout __stack_chk_fail" ]; then
      echo "dovi.ko has unexpected symbol CRC differences:$mismatches" >&2
      exit 1
    fi

    install -Dm0444 "$module" \
      "$out/lib/modules/${kernel.modDirVersion}/extra/dovi.ko"
  '';

  meta = {
    description = "Amlogic Dolby Vision kernel module";
    homepage = "https://discourse.coreelec.org";
    license = lib.licenses.unfreeRedistributable;
    platforms = lib.intersectLists lib.platforms.aarch64 lib.platforms.linux;
  };
}
