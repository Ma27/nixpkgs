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
  linuxKernel
}:

let
  linux = linuxKernel.kernels.linux_7_0;
  #data = builtins.fromJSON (builtins.readFile input);

  # FIXME maybe even a scope? All the on-demand callPackage sucks!
  flags = callPackage ../common-flags.nix { };

  defaultsFromROKC =
    with lib.kernel;
    lib.mkMerge [
      #(lib.genAttrs' data.deferred (
        #name: lib.nameValuePair name (lib.mkOptionDefault (throw "${name} must be set by the Nix code!"))
      #))
      (lib.genAttrs' data.unset (name: lib.nameValuePair name (lib.mkOptionDefault unset)))
      (lib.mapAttrs (lib.const lib.mkOptionDefault) data.declarations)
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
    # FIXME we need a better input format for the flags!
    env =
      lib.genAttrs' flags (
        line:
        let
          data = lib.splitString "=" line;
        in
        lib.nameValuePair (builtins.unsafeDiscardStringContext (lib.head data)) (lib.last data)
      )
      // {
        SRCARCH = "x86";
        KERNELVERSION = version;
        srctree = "."; # FIXME ACH GEHT DOCH SCHEIẞEN
        PAHOLE = "${lib.getExe pahole}";
        CLANG_FLAGS = "-no-integrated-as -fno-integrated-as";
      };
    buildCommand = ''
      source "$NIX_ATTRS_SH_FILE"
      <"$NIX_ATTRS_JSON_FILE" jq -r .configData >$out
      unpackFile ${linux.src}

      pushd linux-7.0.9 &>/dev/null
        env RUST_BACKTRACE=1 /tmp/rokcnix complete -k Kconfig -i ${input} -o $out ${overrides}
        cat $out
        /tmp/rokc -q check "$out" Kconfig
      popd &>/dev/null
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
} // {
  #data = builtins.toFile ".config" config.configFile;
}
