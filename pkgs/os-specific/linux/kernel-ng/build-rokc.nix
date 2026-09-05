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
  rokc,

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
    pname = "linux-.config";
    inherit version src;
    __structuredAttrs = true;
    preferLocalBuild = true;
    nativeBuildInputs = [
      jq
      strace
      #binutils
      breakpointHook
      rokc
    ];
    env =
      commonFlags
      // {
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
      rokcnix complete -k Kconfig -i ${kconfig.inputFile} -o $out ${kconfig.evalOverrides.config.outFile}
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
  overrideEvalTimeConfig = lib.mapAttrs' (
    name:
    {
      freeform ? null,
      tristate ? null,
      ...
    }:
    lib.nameValuePair "CONFIG_${name}" (if tristate == null then freeform else tristate)
  ) (kconfig.declarations // kconfig.evalOverrides.config.custom);
})
// {
  buildtimeConfig = kconfigLib.configAccessor;
}
