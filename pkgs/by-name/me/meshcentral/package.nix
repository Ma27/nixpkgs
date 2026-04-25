{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs_22,
}:

buildNpmPackage (finalAttrs: {
  pname = "meshcentral";
  version = "1.1.59";

  src = fetchFromGitHub {
    owner = "Ylianst";
    repo = "MeshCentral";
    tag = finalAttrs.version;
    hash = "sha256-qfiIofwFOXHzxnqyJyXCgwMqBhONjBiU/5YLOE7u4n8=";
  };

  npmDepsHash = "sha256-UYPx3OIeT1HUgyjY743F/DTwsfIRTlsQLJxK99LbA/k=";
  # Using the npmDeps with a newer nodejs causes `npm ci` errors, also upstream
  # states they stick to the LTS version of nodejs:
  # https://meshcentral.com/docs/MeshCentral2InstallGuide.pdf
  nodejs = nodejs_22;

  patches = [
    ./fix-js-include-paths.patch
    # from some reason the way the package is installed causes the `require`
    # line in `$out/lib/node_modules/meshcentral/bin/meshcentral` to import the
    # main file as a module, and thus nothing happens when it runs. We remove
    # this conditional since we never use this as a module.
    ./run.patch
    # Add `optionalDependencies` that are used during runtime, to
    # `package{,-lock}.json`.
    ./optionalDependencies.patch
  ];

  dontNpmBuild = true;

  meta = {
    description = "Computer management web app";
    homepage = "https://meshcentral.com/";
    maintainers = with lib.maintainers; [ ma27 ];
    license = lib.licenses.asl20;
    mainProgram = "meshcentral";
  };
})
