{
  lib,
  pahole,
  callPackage,
  strace,
  buildPackages,
  breakpointHook,
  binutils,
  version ? "7.0.9",
  # TODO 'readTree' function that derives this JSON from a directory
  # structure that splits via arch/version.
  input ? ./config.json,
  overrides ? ./overrides.json,
  rokc,
  stdenv,
  jq,
  # for kernelPackagesFor
  features ? { },
  kernelPatches ? [ ],
  randstructSeed ? null,
  linuxKernel,

  /*
    TODO
    reenable modules
    no hard-coded version
    rokc pkg
    requiredKernelConfig
    overrides-in-nix
    no dumb overrides in this file
    ensure convergence.
  */
}:

let
  linux = linuxKernel.kernels.linux_7_0;

  # FIXME maybe even a scope? All the on-demand callPackage sucks!
  flags = builtins.removeAttrs (callPackage ../common-flags.nix { }) [
    "__functor"
    "override"
    "overrideDerivation"
  ];

  configfile = stdenv.mkDerivation (finalAttrs: {
    pname = "linux-.config";
    inherit version;
    __structuredAttrs = true;
    inherit (linux) src;
    preferLocalBuild = true;
    nativeBuildInputs = [
      jq
      strace
      binutils
      breakpointHook
      #rokc
      (import ~/Projects/nix-module-system-kernel/rokc/build.nix)
    ];
    env = flags // {
      SRCARCH = "x86";
      KERNELVERSION = version;
      PAHOLE = "${lib.getExe pahole}";
      CLANG_FLAGS = "-no-integrated-as -fno-integrated-as";
    };
    postUnpack = ''
      export srctree="$(realpath "$sourceRoot")"
    '';
    dontBuild = true;
    dontConfigure = true;
    installPhase = ''
      env RUST_BACKTRACE=1 rokcnix complete -k Kconfig -i ${input} -o $out ${overrides}
      cat $out
      rokc -q check "$out" Kconfig
    '';
  });
in
(callPackage ../build.nix { inherit lib stdenv buildPackages; }) {
  pname = "linux";
  inherit (linux) src kernelPatches;
  inherit
    version
    configfile
    ;
  modDirVersion = "7.0.9";
}
