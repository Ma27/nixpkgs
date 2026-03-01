{ rustPlatform, fetchgit }:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "rokc";
  version = "0.0.0-git";
  src = fetchgit {
    url = "https://cl.afnix.fr/rokc/rokc";
    rev = "3b2413698525db7cf15ded2b47f9f734cbf960f4";
    hash = "sha256-MqyMC4eOkb+r+XXas7H0VLd9Ow03XxX7TaPPhU7EW5c=";
  };
  #src = /home/ma27/Projects/nix-module-system-kernel/rokc;
  cargoHash = "sha256-kdJgKzmljMZqIuJPTiN3w3kq14xFaG0o1crk7dupYg0=";
  env.ROKC_VERSION = finalAttrs.version;
})
