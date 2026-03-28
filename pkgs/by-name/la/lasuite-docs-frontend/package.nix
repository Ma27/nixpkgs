{
  lib,
  fetchFromGitHub,
  stdenv,
  fetchpatch,
  fetchYarnDeps,
  nodejs,
  fixup-yarn-lock,
  yarn,
  yarnConfigHook,
  yarnBuildHook,
}:

stdenv.mkDerivation rec {
  pname = "lasuite-docs-frontend";
  version = "4.8.4";

  src = fetchFromGitHub {
    owner = "suitenumerique";
    repo = "docs";
    tag = "v${version}";
    hash = "sha256-k90JxFxXL3vEGBMkgbQABUCK99utJ88E/v9Zcj/2oBo=";
  };

  sourceRoot = "${src.name}/src/frontend";

  patches = [
    # https://github.com/suitenumerique/docs/pull/2147
    (fetchpatch {
      url = "https://github.com/Ma27/lasuite-docs/commit/f3b4ae26394b944cf5e666f983c3533cf32e6def.patch";
      hash = "sha256-Ucw1KtsFrPvtoeeG2fH5L64Jfcog4RV38Qg+EykGcQY=";
      stripLen = 2;
    })
  ];

  offlineCache = fetchYarnDeps {
    yarnLock = "${src}/src/frontend/yarn.lock";
    hash = "sha256-ElI6WWKPCsO7Viexgp2XtcjXAXzFnG2ZPN5PjOaKO2g=";
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
