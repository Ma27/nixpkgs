{
  lib,
  fetchFromGitHub,
  stdenv,
  fetchYarnDeps,
  nodejs,
  fixup-yarn-lock,
  yarn,
  yarnConfigHook,
  yarnBuildHook,
}:

stdenv.mkDerivation rec {
  pname = "lasuite-docs-frontend";
  version = "5.0.0";

  src = fetchFromGitHub {
    owner = "suitenumerique";
    repo = "docs";
    tag = "v${version}";
    hash = "sha256-yjcnXC46C2Z453oN4/fJc2q+B0yQKL3jKaIIpRlzu5s=";
  };

  sourceRoot = "${src.name}/src/frontend";

  offlineCache = fetchYarnDeps {
    yarnLock = "${src}/src/frontend/yarn.lock";
    hash = "sha256-K7AvCt2GMwo+mtTqa3c0OGUGM3Whfo/WfeYG/Vjxhtg=";
  };

  nativeBuildInputs = [
    nodejs
    fixup-yarn-lock
    yarn
    yarnConfigHook
    yarnBuildHook
  ];

  yarnBuildScript = "app:build";

  installPhase = ''
    runHook preInstall

    cp -r apps/impress/out/ $out

    runHook postInstall
  '';

  meta = {
    description = "Collaborative note taking, wiki and documentation platform that scales. Built with Django and React. Opensource alternative to Notion or Outline";
    homepage = "https://github.com/suitenumerique/docs";
    changelog = "https://github.com/suitenumerique/docs/blob/${src.tag}/CHANGELOG.md";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ soyouzpanda ma27 ];
    platforms = lib.platforms.all;
  };
}
