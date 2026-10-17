inputs: final: _prev:

{
  linux-amlogic = final.callPackage ../pkgs/linux-amlogic {
    linuxSource = inputs.coreelec-linux-amlogic;
    commonDriversSource = inputs.coreelec-common-drivers;
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
          src = inputs.coreelec-gpu-aml;
          inherit (kernelFinal) kernel;
        };
        media-modules-aml = final.callPackage ../pkgs/media-modules-aml {
          src = inputs.coreelec-media-modules-aml;
          inherit (kernelFinal) kernel;
        };
      }
    );
}
