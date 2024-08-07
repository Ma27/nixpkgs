{
  lib,
  buildPythonPackage,
  fetchPypi,
  six,
}:

buildPythonPackage rec {
  pname = "multipledispatch";
  version = "1.0.0";
  format = "setuptools";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-XIOZFUZcaCBsPpxHM1eQghbCg4O0JTYeXRRFlL+Fp+A=";
  };

  # No tests in archive
  doCheck = false;

  propagatedBuildInputs = [ six ];

  meta = {
    homepage = "https://github.com/mrocklin/multipledispatch/";
    description = "Relatively sane approach to multiple dispatch in Python";
    license = lib.licenses.bsd3;
  };
}
