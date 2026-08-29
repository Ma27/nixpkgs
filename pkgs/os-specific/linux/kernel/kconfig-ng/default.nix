{
  lib,
  pahole,
  callPackage,
  strace,
  buildPackages,
  breakpointHook,
  binutils,
  modDirVersion,
  version,
  # TODO 'readTree' function that derives this JSON from a directory
  # structure that splits via arch/version.
  input ? ./config.json,
  overrides ? ./overrides.json,
  stdenv,
  jq,
  # for kernelPackagesFor
  kernelPatches ? [ ],
  src,

  /*
    TODO
    rokc pkg
    requiredKernelConfig
    overrides-in-nix
    no dumb overrides in this file
    ensure convergence.
    reenable modules
  */
}:

let
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
    inherit src;
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
      #CLANG_FLAGS = "-no-integrated-as -fno-integrated-as";
    };
    postUnpack = ''
      export srctree="$(realpath "$sourceRoot")"
    '';
    dontBuild = true;
    dontConfigure = true;
    installPhase = ''
      env RUST_BACKTRACE=1 rokcnix complete -k Kconfig -i ${input} -o $out ${builtins.toFile "foo" "{}"}
      cat $out
      rokc -q check "$out" Kconfig
    '';
  });
in
(callPackage ../build.nix { inherit lib stdenv buildPackages; }) {
  pname = "linux";
  inherit src kernelPatches;
  inherit
    version
    configfile
    modDirVersion
    ;
}
