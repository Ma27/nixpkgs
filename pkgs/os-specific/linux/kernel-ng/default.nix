{
  lib,
  newScope,
  packagesFor,
}:

  /*
    TODO
    requiredKernelConfig
      +refactor
    allow usage of both kconfig things
    eval-level assertions for basic shit
    overrides-in-nix
    reenable modules
  */

lib.makeScope newScope (self: {
  kernels = lib.makeExtensible (_: {
    linux_7_0 = self.buildMainline {
      branch = "7.0";
      kernelPatches = [
        self.kernelPatches.bridge_stp_helper
        self.kernelPatches.request_key_helper
      ];

      input = ./cfg/config.json;
      overrides = ./cfg/overrides.json;
    };
  });

  pkgs = lib.makeExtensible (_: {
    linux_7_0 = lib.recurseIntoAttrs (packagesFor self.kernels.linux_7_0);
  });

  # Helpers

  rokc = (import ~/Projects/nix-module-system-kernel/rokc/build.nix); # FIXME replace with proper package!

  buildMainline = self.callPackage ./entrypoint.nix { };

  buildLinuxWithRokc = self.callPackage ./build-rokc.nix;

  kconfigLib = self.callPackage ./kconfig.nix { };

  # Legacy things: using code from os-specific/linux/kernel.

  kernelPatches = self.callPackage ../kernel/patches.nix { };

  buildLinuxWithConfig =
    args: self.callPackage ../kernel/build.nix { } (args // { commonMakeFlags = self.commonFlags; });

  commonFlags = removeAttrs (self.callPackage ../kernel/common-flags.nix { }) [
    "__functor"
    "override"
    "overrideDerivation"
  ];

  allKernels = builtins.fromJSON (builtins.readFile ../kernel/kernels-org.json);
})
