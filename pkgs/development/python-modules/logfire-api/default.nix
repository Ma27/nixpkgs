{
  buildPythonPackage,
  logfire,

  # build system
  hatchling,
}:

buildPythonPackage rec {
  pname = "logfire-api";
  inherit (logfire) version src;
  pyproject = true;

  sourceRoot = "${src.name}/logfire-api";

  build-system = [ hatchling ];

  pythonImportsCheck = [ "logfire_api" ];

  meta = logfire.meta // {
    description = "Shim for the Logfire SDK which does nothing unless Logfire is installed";
  };
}
