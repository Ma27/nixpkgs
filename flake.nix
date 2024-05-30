# Experimental flake interface to Nixpkgs.
# See https://github.com/NixOS/rfcs/pull/49 for details.
{
  description = "A collection of packages for the Nix package manager";

  outputs = { self }:
    let
      jobs = import ./pkgs/top-level/release.nix {
        nixpkgs = self;
      };

      lib = (import ./lib).extend libVersionInfoOverlay;

      libVersionInfoOverlay = finalLib: prevLib: {
        trivial = prevLib.trivial // {
          versionSuffix =
            ".${finalLib.substring 0 8 (self.lastModifiedDate or self.lastModified or "19700101")}.${self.shortRev or "dirty"}";
          version = finalLib.trivial.release + finalLib.trivial.versionSuffix;
          revisionWithDefault = default: self.rev or default;
        };
      };

      forAllSystems = lib.genAttrs lib.systems.flakeExposed;
    in
    {
      overlays.default = final: prev: {
        lib = prev.lib.extend libVersionInfoOverlay;
      };

      lib = lib.extend (final: prev: {

        nixos = import ./nixos/lib { lib = final; };

        nixosSystem = args:
          import ./nixos/lib/eval-config.nix (
            args // { inherit (self) lib; } // lib.optionalAttrs (! args?system) {
              # Allow system to be set modularly in nixpkgs.system.
              # We set it to null, to remove the "legacy" entrypoint's
              # non-hermetic default.
              system = null;
            }
          );
      });

      checks.x86_64-linux.tarball = jobs.tarball;

      htmlDocs = {
        nixpkgsManual = jobs.manual;
        nixosManual = (import ./nixos/release-small.nix {
          nixpkgs = self;
        }).nixos.manual.x86_64-linux;
      };

      # The "legacy" in `legacyPackages` doesn't imply that the packages exposed
      # through this attribute are "legacy" packages. Instead, `legacyPackages`
      # is used here as a substitute attribute name for `packages`. The problem
      # with `packages` is that it makes operations like `nix flake show
      # nixpkgs` unusably slow due to the sheer number of packages the Nix CLI
      # needs to evaluate. But when the Nix CLI sees a `legacyPackages`
      # attribute it displays `omitted` instead of evaluating all packages,
      # which keeps `nix flake show` on Nixpkgs reasonably fast, though less
      # information rich.
      legacyPackages = forAllSystems (system: import ./. {
        inherit system;
        # XXX custom patch from @Ma27. This is the default config I use for my deployment
        # (and this patch should only appear on my deployment's tracking-branch).
        # Workaround here because there's no reasonable way to (re)configure nixpkgs without
        # having to instantiate a second one.
        config = {
          allowUnfree = false;
          allowUnfreePredicate = with lib;
            drv: elem (builtins.parseDrvName (drv.name or drv.pname)).name [
              "chrome-widevine-cdm"
              "chromium"
              "chromium-binary-plugin-widevine"
              "widevine-cdm"
              "chromium-unwrapped"
              "spotify"
              "spotify-unwrapped"
              "steam"
              "steam-original"
              "steam-run"
              # for work
              "1password-cli"
            ];
          chromium.enableWideVine = true;
        };
        overlays = [ self.overlays.default ];
      });

      nixosModules = {
        notDetected = ./nixos/modules/installer/scan/not-detected.nix;

        /*
          Make the `nixpkgs.*` configuration read-only. Guarantees that `pkgs`
          is the way you initialize it.

          Example:

              {
                imports = [ nixpkgs.nixosModules.readOnlyPkgs ];
                nixpkgs.pkgs = nixpkgs.legacyPackages.x86_64-linux;
              }
        */
        readOnlyPkgs = ./nixos/modules/misc/nixpkgs/read-only.nix;
      };
    };
}
