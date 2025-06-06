{
  lib,
  fetchFromGitHub,
  python3,
  gettext,
}:

python3.pkgs.buildPythonApplication rec {
  pname = "linkchecker";
  version = "10.2.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "linkchecker";
    repo = "linkchecker";
    tag = "v${version}";
    hash = "sha256-z7Qp74cai8GfsxB4n9dSCWQepp0/4PimFiRJQBaVSoo=";
  };

  nativeBuildInputs = [ gettext ];

  build-system = with python3.pkgs; [
    hatchling
    hatch-vcs
    polib # translations
  ];

  dependencies = with python3.pkgs; [
    argcomplete
    beautifulsoup4
    dnspython
    requests
  ];

  nativeCheckInputs = with python3.pkgs; [
    pyopenssl
    parameterized
    pytestCheckHook
  ];

  disabledTests = [
    "TestLoginUrl"
    "test_timeit2" # flakey, and depends sleep being precise to the milisecond
    "test_internet" # uses network, fails on Darwin (not sure why it doesn't fail on linux)
    "test_markdown" # uses sys.version_info for conditional testing
    "test_itms_services" # uses sys.version_info for conditional testing
  ];

  disabledTestPaths = [
    "tests/checker/telnetserver.py"
    "tests/checker/test_telnet.py"
  ];

  __darwinAllowLocalNetworking = true;

  meta = {
    description = "Check websites for broken links";
    mainProgram = "linkchecker";
    homepage = "https://linkcheck.github.io/linkchecker/";
    changelog = "https://github.com/linkchecker/linkchecker/releases/tag/v${version}";
    license = lib.licenses.gpl2Plus;
    maintainers = with lib.maintainers; [
      peterhoeg
      tweber
    ];
  };
}
