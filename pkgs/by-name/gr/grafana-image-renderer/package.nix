{
  lib,
  buildGo125Module,
  fetchFromGitHub,
}:

buildGo125Module (finalAttrs: {
  pname = "grafana-image-renderer";
  version = "5.0.9";

  src = fetchFromGitHub {
    owner = "grafana";
    repo = "grafana-image-renderer";
    tag = "v${finalAttrs.version}";
    hash = "sha256-3tyeRMS1w0AWva83k5Lpy2NXL+4qAk1Tm9RQ8A+FqJk=";
  };

  vendorHash = "sha256-rENAsvd/WGIPmIatf7MwIMhxATG0cMhn6WO/MJFurfk=";

  subPackages = [ "." ];

  meta = with lib; {
    homepage = "https://github.com/grafana/grafana-image-renderer";
    description = "Grafana backend plugin that handles rendering of panels & dashboards to PNGs using headless browser (Chromium/Chrome)";
    mainProgram = "grafana-image-renderer";
    license = licenses.asl20;
    maintainers = with maintainers; [ ma27 ];
  };
})
