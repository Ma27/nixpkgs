{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule (finalAttrs: {
  pname = "grafana-image-renderer";
  version = "5.0.8";

  src = fetchFromGitHub {
    owner = "grafana";
    repo = "grafana-image-renderer";
    rev = "v${finalAttrs.version}";
    hash = "sha256-6j02NnjTm67LbBk+LrErQvkaJH/DVl3kQaSnIilidVI=";
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
