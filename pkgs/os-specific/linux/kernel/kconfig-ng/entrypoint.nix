# Adaptation of mainline.nix, not decided yet if that's needed in the final form of this project.
let
  allKernels = builtins.fromJSON (builtins.readFile ../kernels-org.json);
in

{
  branch,
  kernelPatches,
  lib,
  fetchurl,
  overrides,
  input,
  callPackage,
  ...
}:

let
  thisKernel = allKernels.${branch};
  inherit (thisKernel) version;

  src = fetchurl {
    url = "mirror://kernel/linux/kernel/v${lib.versions.major version}.x/linux-${version}.tar.xz";
    inherit (thisKernel) hash;
  };
in
callPackage ./. {
  inherit src kernelPatches version input overrides;
  modDirVersion = lib.versions.pad 3 version;
}
