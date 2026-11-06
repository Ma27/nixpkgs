{
  buildPythonApplication,
  e2fsprogs,
  iproute2,
  lib,
  ruff,
  setuptools,
  util-linux,
  mkosi,
  systemd,
  ty,
}:

buildPythonApplication {
  pname = "run-nspawn";
  version = "1.0";
  pyproject = true;

  src = ./src;

  postPatch = ''
    substituteInPlace run_nspawn/__init__.py \
      --replace-fail "@systemd-nspawn@" "${lib.getExe' systemd "systemd-nspawn"}" \
      --replace-fail "@systemd-dissect@" "${lib.getExe' systemd "systemd-dissect"}" \
      --replace-fail "@mkosi-sandbox@" "${lib.getExe' mkosi "mkosi-sandbox"}" \
      --replace-fail "@unshare@" "${lib.getExe' util-linux "unshare"}" \
      --replace-fail "@chattr@" "${lib.getExe' e2fsprogs "chattr"}"
  '';

  build-system = [
    setuptools
  ];

  propagatedBuildInputs = [
    systemd
    iproute2
  ];

  doCheck = true;

  nativeCheckInputs = [
    ruff
    ty
  ];

  checkPhase = ''
    echo -e "\x1b[32m## run ty\x1b[0m"
  '';

  meta = {
    mainProgram = "run-nspawn";
  };
}
