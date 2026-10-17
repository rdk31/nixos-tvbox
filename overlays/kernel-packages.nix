final: _prev:

{
  linux-amlogic = final.callPackage ../pkgs/linux-amlogic {
    linuxSource = final.coreelecSources.linux-amlogic;
    commonDriversSource = final.coreelecSources.common-drivers;
    features = { };
    kernelPatches = [ ];
    randstructSeed = "";
  };
  linuxPackagesForAmlogic =
    kernel:
    (final.linuxPackagesFor kernel).extend (
      kernelFinal: _kernelPrev: {
        dovi-module = final.callPackage ../pkgs/dovi-module {
          inherit (kernelFinal) kernel;
        };
        gpu-aml = final.callPackage ../pkgs/gpu-aml {
          src = final.coreelecSources.gpu-aml;
          inherit (kernelFinal) kernel;
        };
        media-modules-aml = final.callPackage ../pkgs/media-modules-aml {
          src = final.coreelecSources.media-modules-aml;
          inherit (kernelFinal) kernel;
        };
      }
    );
}
