{ lib
, stdenv
, fetchFromGitHub
, python3
, openssl
, rustPlatform
, nixosTests
, callPackage
}:

let
  plugins = python3.pkgs.callPackage ./plugins { };
  tools = callPackage ./tools { };
in
python3.pkgs.buildPythonApplication rec {
  pname = "matrix-synapse";
  version = "1.84.0";
  format = "pyproject";

  src = fetchFromGitHub {
    owner = "matrix-org";
    repo = "synapse";
    rev = "v${version}";
    hash = "sha256-CN/TCyQLlGRNDvsojGltP+GQ4UJiWQZkgQinD/w9Lfc=";
  };

  cargoDeps = rustPlatform.fetchCargoTarball {
    inherit src;
    name = "${pname}-${version}";
    hash = "sha256-MikdIo1YghDAvpVX2vUHFmz8WgupUi/TbMPIvYgGFRA=";
  };

  postPatch = ''
    # Remove setuptools_rust from runtime dependencies
    # https://github.com/matrix-org/synapse/blob/v1.69.0/pyproject.toml#L177-L185
    sed -i '/^setuptools_rust =/d' pyproject.toml
  '';

  nativeBuildInputs = with python3.pkgs; [
    poetry-core
    rustPlatform.cargoSetupHook
    setuptools-rust
  ] ++ (with rustPlatform.rust; [
    cargo
    rustc
  ]);

  buildInputs = [
    openssl
  ];

  propagatedBuildInputs = with python3.pkgs; [
    attrs
    bcrypt
    bleach
    canonicaljson
    cryptography
    ijson
    immutabledict
    jinja2
    jsonschema
    matrix-common
    msgpack
    netaddr
    packaging
    phonenumbers
    pillow
    prometheus-client
    pyasn1
    pyasn1-modules
    pydantic
    pymacaroons
    pyopenssl
    pyyaml
    service-identity
    signedjson
    sortedcontainers
    treq
    twisted
    typing-extensions
    unpaddedbase64
  ]
  # extras
  ++ twisted.optional-dependencies.tls;

  checkInputs = with python3.pkgs; [ mock parameterized openssl ];

  passthru.optional-dependencies = with python3.pkgs; {
    matrix-synapse-ldap3 = with plugins; [
      matrix-synapse-ldap3
    ];
    postgres = if isPyPy then [
      psycopg2cffi
    ] else [
      psycopg2
    ];
    saml2 = [
      pysaml2
    ];
    oidc = [
      authlib
    ];
    systemd = lib.optionals (lib.meta.availableOn stdenv.hostPlatform systemd) [
      systemd
    ];
    url-preview = [
      lxml
    ];
    sentry = [
      sentry-sdk
    ];
    opentracing = [
      jaeger-client
      opentracing
    ];
    jwt = [
      authlib
    ];
    redis = [
      hiredis
      txredisapi
    ];
    cache-memory = [
      pympler
    ];
    user-search = [
      PyICU
    ];
  };

  doCheck = !stdenv.isDarwin;

  checkPhase = ''
    runHook preCheck

    # remove src module, so tests use the installed module instead
    rm -rf ./synapse

    PYTHONPATH=".:$PYTHONPATH" ${python3.interpreter} -m twisted.trial -j $NIX_BUILD_CORES tests

    runHook postCheck
  '';

  passthru.tests = { inherit (nixosTests) matrix-synapse; };
  passthru.plugins = plugins;
  passthru.tools = tools;
  passthru.python = python3;

  meta = with lib; {
    homepage = "https://matrix.org";
    changelog = "https://github.com/matrix-org/synapse/releases/tag/v${version}";
    description = "Matrix reference homeserver";
    license = licenses.asl20;
    maintainers = teams.matrix.members;
  };
}
