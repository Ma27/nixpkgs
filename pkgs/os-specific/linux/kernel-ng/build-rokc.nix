{
  modDirVersion,
  version,
  input,
  overrides,
  kernelPatches ? [ ],
  src,

  lib,
  pahole,
  binutils,
  stdenv,
  jq,

  commonFlags,
  buildLinuxWithConfig,

  strace,
  breakpointHook,

  # FIXME get rid of that, only to please the NixOS API calling this.
  features ? { },
  randstructSeed ? null,

  /*
    TODO
    requiredKernelConfig
    overrides-in-nix
    no dumb overrides in this file
    ensure convergence.
    reenable modules
  */
}:

let
  configfile = stdenv.mkDerivation (finalAttrs: {
    pname = "linux-.config";
    inherit version src;
    __structuredAttrs = true;
    preferLocalBuild = true;
    nativeBuildInputs = [
      jq
      strace
      binutils
      breakpointHook
      #rokc
      (import ~/Projects/nix-module-system-kernel/rokc/build.nix)
    ];
    env = commonFlags // {
      # FIXME this is obviously very incomplete.
      SRCARCH =
        let
          arch = stdenv.hostPlatform.linuxArch;
        in
        if arch == "x86_64" then "x86" else arch;
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
(buildLinuxWithConfig {
  pname = "linux";
  inherit src kernelPatches;
  inherit
    version
    configfile
    modDirVersion
    ;
})
// rec {
  config =
    let
      config_ = (builtins.fromJSON (builtins.readFile input)).declarations;
    in

    let
      attrName = attr: attr;
    in
    {
      isSet = attr: lib.hasAttr (attrName attr) config;

      getValue =
        attr:
        if config.isSet attr then
          let
            i = lib.getAttr (attrName attr) config;
          in
          i.tristate or i.freeform
        else
          null;

      isYes = attr: (config.getValue attr) == "y";

      isNo = attr: (config.getValue attr) == "n";

      isModule = attr: (config.getValue attr) == "m";

      isEnabled = attr: (config.isModule attr) || (config.isYes attr);

      isDisabled = attr: (!(config.isSet attr)) || (config.isNo attr);
    }
    // config_;
}
