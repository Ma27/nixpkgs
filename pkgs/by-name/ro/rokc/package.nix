{ rustPlatform, fetchgit, lib }:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "rokc";
  version = "0.0.0-git";
  #src = /home/ma27/Projects/nix-module-system-kernel/rokc;
  src = lib.fileset.toSource {
    root = /home/ma27/Projects/nix-module-system-kernel/rokc;
    fileset = lib.fileset.unions [
      /home/ma27/Projects/nix-module-system-kernel/rokc/cli
      /home/ma27/Projects/nix-module-system-kernel/rokc/core
      /home/ma27/Projects/nix-module-system-kernel/rokc/nix
      /home/ma27/Projects/nix-module-system-kernel/rokc/parser
      /home/ma27/Projects/nix-module-system-kernel/rokc/rokcnix
      /home/ma27/Projects/nix-module-system-kernel/rokc/subprojects
      /home/ma27/Projects/nix-module-system-kernel/rokc/types
      /home/ma27/Projects/nix-module-system-kernel/rokc/Cargo.lock
      /home/ma27/Projects/nix-module-system-kernel/rokc/Cargo.toml
    ];
  };
  env.ROKC_VERSION = finalAttrs.version;
  cargoLock.lockFile = /home/ma27/Projects/nix-module-system-kernel/rokc/Cargo.lock;
})
