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
}:

let
  linux = linuxKernel.kernels.linux_7_0;
  #data = builtins.fromJSON (builtins.readFile input);

  # FIXME maybe even a scope? All the on-demand callPackage sucks!
  flags = builtins.removeAttrs (callPackage ../common-flags.nix { }) [
    "__functor"
    "override"
    "overrideDerivation"
  ];

  #inherit
  #(lib.evalModules {
  #modules = [
  #../../../../../nixos/modules/system/boot/kernel_config.nix
  #{
  #settings = defaultsFromROKC;
  #_file = "rokc defaults from ${toString input}";
  #}
  #{
  #settings = callPackage ./nix-overrides.nix { inherit version; };
  #_file = toString ./nix-overrides.nix;
  #}
  #];
  #})
  #config
  #;

  configfile = stdenv.mkDerivation (finalAttrs: {
    pname = "linux-.config";
    inherit version;
    __structuredAttrs = true;
    inherit (linux) src;
    #configData = config.configFile;
    #passthru = {
    #configModule = config;
    #config = config.settings;
    #};
    preferLocalBuild = true;
    nativeBuildInputs = [
      jq
      strace
      binutils
      breakpointHook
      #rokc
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
      env RUST_BACKTRACE=1 /tmp/rokcnix complete -k Kconfig -i ${input} -o $out ${overrides}
      cat $out
      /tmp/rokc -q check "$out" Kconfig
    '';
  });
in
(callPackage ../build.nix { inherit lib stdenv buildPackages; }) {
  pname = "linux";
  inherit (linux) src kernelPatches;
  inherit
    version
    #randstructSeed
    #extraMakeFlags
    #extraMeta
    configfile
    #modDirVersion
    ;
  #allowImportFromDerivation = true;
  #config = config;
  modDirVersion = "7.0.9";
  #pos = builtins.unsafeGetAttrPos "version" args;
}
// {
  #data = builtins.toFile ".config" config.configFile;
}
