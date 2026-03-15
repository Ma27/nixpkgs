{
  lib,
  pahole,
  callPackage,
  buildPackages,
  version ? "6.18.10",
  # TODO 'readTree' function that derives this JSON from a directory
  # structure that splits via arch/version.
  input ? ./kconfig-x86_64.json,
  rokc,
  stdenv,
  jq,
  linux,
  # for kernelPackagesFor
  features ? { },
  kernelPatches ? [ ],
  randstructSeed ? null,
}:

let
  data = builtins.fromJSON (builtins.readFile input);

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

  inherit
    (lib.evalModules {
      modules = [
        ../../../../../nixos/modules/system/boot/kernel_config.nix
        {
          settings = defaultsFromROKC;
          _file = "rokc defaults from ${toString input}";
        }
        {
          settings = callPackage ./nix-overrides.nix { inherit version; };
          _file = toString ./nix-overrides.nix;
        }
      ];
    })
    config
    ;

  configfile = stdenv.mkDerivation (finalAttrs: {
    pname = "linux-.config";
    inherit version;
    __structuredAttrs = true;
    configData = config.configFile;
    passthru = {
      configModule = config;
      config = config.settings;
    };
    preferLocalBuild = true;
    nativeBuildInputs = [
      jq
      rokc
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
        srctree = "${linux.name}";
        PAHOLE = "${lib.getExe pahole}";
        CLANG_FLAGS = "";
      };
    buildCommand = ''
      source "$NIX_ATTRS_SH_FILE"
      <"$NIX_ATTRS_JSON_FILE" jq -r .configData >$out
      unpackFile ${linux.src}
      rokc -q check "$out" ${linux.name}/Kconfig
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
  config = config.configStrings;
  modDirVersion = "6.18.15";
  #pos = builtins.unsafeGetAttrPos "version" args;
} // {
  data = builtins.toFile ".config" config.configFile;
}
