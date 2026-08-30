{
  allKernels,
  lib,
  fetchurl,
  buildLinuxWithRokc,
  kconfigLib,
}:

lib.makeOverridable (
  {
    branch,
    input,
    overrides,
    kernelPatches,
  }:

  let
    thisKernel = allKernels.${branch};
    inherit (thisKernel) version;

    src = fetchurl {
      url = "mirror://kernel/linux/kernel/v${lib.versions.major version}.x/linux-${version}.tar.xz";
      inherit (thisKernel) hash;
    };
  in
  buildLinuxWithRokc {
    inherit
      src
      kernelPatches
      version
      ;
    modDirVersion = lib.versions.pad 3 version;

    kconfig = kconfigLib.mkKConfigEvaluator input overrides;
  }
)
