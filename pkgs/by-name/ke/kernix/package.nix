{
  lib,
  fetchgit,
  rustPlatform,
}:

rustPlatform.buildRustPackage {
  pname = "kernix";
  version = "0.1.0";

  src = fetchgit {
    url = "https://git.afnix.fr/rokc/kernix.git";
    rev = "229b2d8dab354e72d9dc0121911e2b78abc6237b";
    hash = "sha256-jICSZrSDaDIrwIaDlKVmEw/vh1FxtJSH6jdbnRc6kRk=";
  };

  cargoHash = "sha256-UKK90bcJ2c19iu/RCK9978s7rhK6CvnlC2SAx0S9FEc=";

  meta = with lib; {
    homepage = "https://git.afnix.fr/rokc/kernix";
    license = licenses.mit;
    maintainers = with lib.maintainers; [
      nikstur
      ma27
    ];
    mainProgram = "kernix";
  };
}
