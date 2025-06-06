{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "opcr-policy";
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "opcr-io";
    repo = "policy";
    rev = "v${version}";
    sha256 = "sha256-vTUlC/LQTQEpzd1AXgcJJBZXmbSuX8JACbM60KVuT9E=";
  };
  vendorHash = "sha256-3KBHK9CKn9h45eq0wAwLivm3Lj3COGYn/zGltonLP9k=";

  ldflags = [
    "-s"
    "-w"
    "-X github.com/opcr-io/policy/pkg/version.ver=${version}"
  ];

  subPackages = [ "cmd/policy" ];
  # disable go workspaces
  env.GOWORK = "off";

  doCheck = false;

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    $out/bin/policy --help
    $out/bin/policy version | grep "version: ${version}"

    runHook postInstallCheck
  '';

  meta = {
    mainProgram = "policy";
    homepage = "https://www.openpolicyregistry.io/";
    changelog = "https://github.com/opcr-io/policy/releases/tag/v${version}";
    description = "CLI for managing authorization policies";
    longDescription = ''
      The policy CLI is a tool for building, versioning and publishing your authorization policies.
      It uses OCI standards to manage artifacts, and the Open Policy Agent (OPA) to compile and run.
    '';
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [
      naphta
      jk
    ];
  };
}
