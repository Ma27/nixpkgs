{
  modDirVersion,
  version,
  kconfig,
  kernelPatches ? [ ],
  src,

  lib,
  pahole,
  binutils,
  stdenv,
  jq,
  kernix,

  commonFlags,
  buildLinuxWithConfig,
  kconfigLib,

  strace,
  breakpointHook,

  # FIXME get rid of that, only to please the NixOS API calling this.
  features ? { },
  randstructSeed ? null,
}:

let
  configfile = stdenv.mkDerivation (finalAttrs: {
    pname = "linux.config";
    inherit version src;
    __structuredAttrs = true;
    preferLocalBuild = true;
    nativeBuildInputs = [
      jq
      strace
      #binutils
      breakpointHook
      kernix
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
      RUST_BACKTRACE = "1";
    };
    postUnpack = ''
      export srctree="$(realpath "$sourceRoot")"
    '';
    dontBuild = true;
    dontConfigure = true;
    installPhase = ''
      kernix complete -k Kconfig -i ${kconfig.inputFile} -o $out ${kconfig.evalOverrides.config.outFile}
      cat $out
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
  overrideEvalTimeConfig = lib.mapAttrs' (
    name:
    {
      freeform ? null,
      tristate ? null,
      ...
    }:
    lib.nameValuePair "CONFIG_${name}" (if tristate == null then freeform else tristate)
  ) (kconfig.declarations // kconfig.evalOverrides.config.custom);
}).overrideAttrs
  {
    shellHook = ''
      export SRCARCH="x86"
      export CLANG_FLAGS=""
      export srctree="."
      export BINDGEN=bindgen
      export PAHOLE=pahole
      export RUSTC=rustc
      export ARCH=x86
      export PYTHON3=python3
      export USERLDFLAGS=""
      export USERCFLAGS=""
      export CC_VERSION_TEXT="23.42"
      export KERNELVERSION="6.18.1"
      export RUSTC_VERSION_TEXT="1.95"
    '';
  }
// {
  buildtimeConfig = kconfigLib.configAccessor;
}
