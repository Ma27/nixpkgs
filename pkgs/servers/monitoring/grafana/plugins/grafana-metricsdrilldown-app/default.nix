{ grafanaPlugin, lib }:

grafanaPlugin {
  pname = "grafana-metricsdrilldown-app";
  version = "1.0.13";
  zipHash = "sha256-/4NRoPOeg7N8tjG7tAAs6FSBy9dfxKC1XyU8j9eBO9A=";
  meta = with lib; {
    description = "The Grafana Metrics Drilldown app provides a queryless experience for browsing Prometheus-compatible metrics. Quickly find related metrics without writing PromQL queries.";
    license = licenses.agpl3Only;
    teams = [ lib.maintainers.marcel ];
    platforms = platforms.unix;
  };
}
