{
  lib,
  newScope,
  packagesFor,
}:

/*
  TODO
  compare built config with previous version
  llvm
*/

lib.makeScope newScope (self: {
  kernels = lib.makeExtensible (_: {
    linux_7_2 = self.buildMainline {
      branch = "7.2";
      kernelPatches = [
        self.kernelPatches.bridge_stp_helper
        self.kernelPatches.request_key_helper
      ];
      input = ./cfg/7_2.json;
    };
  });

  pkgs = lib.makeExtensible (_: {
    linux_7_2 = lib.recurseIntoAttrs (packagesFor self.kernels.linux_7_2);
  });

  # Helpers

  buildMainline = self.callPackage ./build-mainline.nix { };

  buildLinuxWithKernix = self.callPackage ./build-linux-with-kernix.nix;

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
