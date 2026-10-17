{
  lib,
  stdenv,
  src,

  kmod,
  kernel,
}:

stdenv.mkDerivation {
  pname = "gpu-aml-valhall-csf";
  version = src.rev;
  inherit src;

  sourceRoot = "source/valhall/r44p0/kernel/drivers/gpu/arm";
  nativeBuildInputs = kernel.moduleBuildDependencies ++ [ kmod ];
  hardeningDisable = [
    "pic"
    "format"
  ];

  postPatch = ''
    substituteInPlace midgard/mali_kbase_core_linux.c \
      --replace-fail \
        '{ .compatible = "arm,mali-valhall" },' \
        '{ .compatible = "arm,mali-valhall-csf" },'
  '';

  buildPhase = ''
    runHook preBuild
    make \
      KERNEL_SRC=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
      CONFIG_MALI_DEVFREQ=y \
      CONFIG_MALI_CSF_SUPPORT=y \
      KCFLAGS="-I${kernel.src}/include -DCONFIG_MALI_LOW_MEM=0"
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    moduleDir="$out/lib/modules/${kernel.modDirVersion}/extra/gpu-aml"
    mkdir -p "$moduleDir"
    install -m 0644 midgard/mali_kbase.ko "$moduleDir/mali_kbase.ko"

    test "$(modinfo -F name "$moduleDir/mali_kbase.ko")" = mali_kbase
    case "$(modinfo -F vermagic "$moduleDir/mali_kbase.ko")" in
      "${kernel.modDirVersion} "*) ;;
      *) echo "gpu-aml vermagic does not match ${kernel.modDirVersion}" >&2; exit 1 ;;
    esac
    modinfo -F alias "$moduleDir/mali_kbase.ko" \
      | grep -q 'of:N.*T.*Carm,mali-valhall-csf'

    runHook postInstall
  '';

  meta = {
    description = "CoreELEC Mali Valhall CSF kernel driver for the Amlogic S6";
    homepage = "https://github.com/CoreELEC/gpu-aml";
    license = lib.licenses.gpl2Only;
    platforms = lib.intersectLists lib.platforms.aarch64 lib.platforms.linux;
  };
}
