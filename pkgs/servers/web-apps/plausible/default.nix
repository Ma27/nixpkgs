{ stdenv, beamPackages, lib, fetchFromGitHub, glibcLocales, git, cacert
, mkYarnModules, nodejs
}:

let
  name = "plausible";
  version = "1.1.1";
  src = fetchFromGitHub {
    owner = "plausible";
    repo = "analytics";
    rev = "v${version}";
    sha256 = "sha256-L3g0va/dxt954MsJUv9vVUANfLo+pklSAxL4eXS10fw=";
  };

  yarnEnv = mkYarnModules {
    pname = name;
    inherit name version;
    packageJSON = ../../../../analytics/assets/package.json;
    yarnNix = ../../../../analytics/assets/yarn2.nix;
    yarnLock = ../../../../analytics/assets/yarn.lock;
  };

  deps = stdenv.mkDerivation {
    name = "${name}-deps";
    inherit src;

    buildPhase = ''
      export HOME=$(mktemp -d)
      export MIX_ENV=prod
      export MIX_DEPS_PATH="${placeholder "out"}"
      mix deps.get --only prod
      find "$out" -path '*/.git/*' -a ! -name HEAD -exec rm -rf {} +
    '';

    dontInstall = true;

    nativeBuildInputs = with beamPackages; [ hex elixir git cacert ];

    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = "sha256-vjN8UMfMTrIYaHsFRWahfQf5Z8C9yimZGXS+pFbeawc=";
  };
in

beamPackages.buildMix {
  name = "${name}-final";
  inherit version src;

  nativeBuildInputs = [ git ];

  postPatch = ''
    sed -ie '/cache_static_manifest/d' config/releases.exs
  '';

  preBuild = ''
    deps=$(mktemp -d)
    mkdir deps
    cp --no-preserve=mode -r ${deps}/* $deps
    cp --no-preserve=mode -r ${deps}/* deps
    export MIX_DEPS_PATH=$deps
    export MIX_REBAR="${beamPackages.rebar}/bin/rebar"
    export MIX_REBAR3="${beamPackages.rebar3}/bin/rebar3"
    export MIX_ENV=prod
    mkdir -p $out
    ln -sf ${yarnEnv}/node_modules assets/node_modules
    mix deps.compile --path $out --no-deps-check
    mix compile --no-deps-check --path $out
    #mix do deps.loadpaths --no-deps-check, phx.digest
    mix release plausible --no-deps-check --path $out
  '';

  LANG = "en_US.UTF-8";
  LOCALE_ARCHIVE = lib.optionalString stdenv.isLinux
    "${glibcLocales}/lib/locale/locale-archive";
}
