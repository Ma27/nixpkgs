{
  lib,
  rustPlatform,
  fetchFromGitHub,
  nixVersions,
  nixosTests,
  boost,
  pkg-config,
  stdenv,
  installShellFiles,
  crates ? [ "attic-client" ],
}:
let
  # Only the attic-client crate builds against the Nix C++ libs
  # This derivation is also used to build the server
  needNixInclude = lib.elem "attic-client" crates;
in
rustPlatform.buildRustPackage {
  pname = "attic";
  version = "0-unstable-2025-05-29";

  src = fetchFromGitHub {
    owner = "zhaofengli";
    repo = "attic";
    rev = "ce9373715fe3fac7a174a65a7e6d6baeba8cb4f9";
    hash = "sha256-CvaKOUq8G10sghKpZhEB2UYjJoWhEkrDFggDgi7piUI=";
  };

  nativeBuildInputs = [
    pkg-config
    installShellFiles
  ];

  buildInputs = lib.optional needNixInclude nixVersions.nix_2_24 ++ [
    boost
  ];

  cargoBuildFlags = lib.concatMapStrings (c: "-p ${c} ") crates;
  cargoHash = "sha256-AbpWnYfBMrR6oOfy2LkQvIPYsClCWE89bJav+iHTtLM=";
  useFetchCargoVendor = true;

  env =
    {
      ATTIC_DISTRIBUTOR = "nixpkgs";
    }
    // lib.optionalAttrs needNixInclude {
      NIX_INCLUDE_PATH = "${lib.getDev nixVersions.nix_2_24}/include";
    };

  # Attic interacts with Nix directly and its tests require trusted-user access
  # to nix-daemon to import NARs, which is not possible in the build sandbox.
  doCheck = false;

  postInstall = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    if [[ -f $out/bin/attic ]]; then
      installShellCompletion --cmd attic \
        --bash <($out/bin/attic gen-completions bash) \
        --zsh <($out/bin/attic gen-completions zsh) \
        --fish <($out/bin/attic gen-completions fish)
    fi
  '';

  passthru = {
    tests = {
      inherit (nixosTests) atticd;
    };

    updateScript = ./update.sh;
  };

  meta = with lib; {
    description = "Multi-tenant Nix Binary Cache";
    homepage = "https://github.com/zhaofengli/attic";
    license = licenses.asl20;
    maintainers = with maintainers; [
      zhaofengli
      aciceri
    ];
    platforms = platforms.linux ++ platforms.darwin;
    mainProgram = "attic";
  };
}
