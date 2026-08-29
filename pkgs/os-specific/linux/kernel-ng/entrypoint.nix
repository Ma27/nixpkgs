{
  allKernels,
  lib,
  fetchurl,
  buildLinuxWithRokc,
}:

{
  branch,
  overrides,
  input,
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
    input
    overrides
    ;
  modDirVersion = lib.versions.pad 3 version;
}
