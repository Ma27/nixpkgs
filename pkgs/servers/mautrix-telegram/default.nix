{
  lib,
  python3,
  fetchPypi,
  fetchpatch,
  fetchFromGitHub,
  withE2BE ? true,
}:

let
  python = python3.override {
    self = python;
    packageOverrides = self: super: {
      # https://github.com/mautrix/python/pull/168
      mautrix = (super.mautrix.override { withOlm = withE2BE; }).overridePythonAttrs (
        {
          patches ? [ ],
          ...
        }:
        {
          patches = patches ++ [
            (fetchpatch {
              url = "https://github.com/mautrix/python/commit/c964dbcc0ed880e6328ff92f81ef62153d43b4fc.patch";
              hash = "sha256-12tnqv8KIfsO7+EX2G9S2nVEXnaqv5dt3lujGpcQCcI=";
            })
          ];
        }
      );
      tulir-telethon = self.telethon.overridePythonAttrs (oldAttrs: rec {
        version = "1.99.0a6";
        pname = "tulir_telethon";
        src = fetchPypi {
          inherit pname version;
          hash = "sha256-ewqc6s5xXquZJTZVBsFmHeamBLDw6PnTSNcmTNKD0sk=";
        };
        doCheck = false;
      });
    };
  };
in
python.pkgs.buildPythonPackage rec {
  pname = "mautrix-telegram";
  version = "0.15.3";
  disabled = python.pythonOlder "3.8";

  src = fetchFromGitHub {
    owner = "mautrix";
    repo = "telegram";
    tag = "v${version}";
    hash = "sha256-w3BqWyAJV/lZPoOFDzxhootpw451lYruwM9efwS6cEc=";
  };

  format = "setuptools";

  patches = [
    ./0001-Re-add-entrypoint.patch
    # https://github.com/mautrix/telegram/pull/955
    (fetchpatch {
      url = "https://github.com/mautrix/telegram/commit/738381a04f4c75346e74afa4b14f330d69cd0f6d.patch";
      hash = "sha256-qvzIk+UvHEmQ7JYu9ytzxR7RZiW0iNr0WiFRSHbZLAM=";
    })
  ];

  propagatedBuildInputs =
    with python.pkgs;
    (
      [
        ruamel-yaml
        python-magic
        commonmark
        aiohttp
        yarl
        mautrix
        tulir-telethon
        asyncpg
        mako
        setuptools
        # speedups
        cryptg
        aiodns
        brotli
        # qr_login
        pillow
        qrcode
        # formattednumbers
        phonenumbers
        # metrics
        prometheus-client
        # sqlite
        aiosqlite
        # proxy support
        pysocks
      ]
      ++ lib.optionals withE2BE [
        # e2be
        python-olm
        pycryptodome
        unpaddedbase64
      ]
    );

  # has no tests
  doCheck = false;

  meta = with lib; {
    homepage = "https://github.com/mautrix/telegram";
    description = "Matrix-Telegram hybrid puppeting/relaybot bridge";
    license = licenses.agpl3Plus;
    platforms = platforms.linux;
    maintainers = with maintainers; [
      nyanloutre
      ma27
      nickcao
    ];
    mainProgram = "mautrix-telegram";
  };
}
