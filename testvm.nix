{
  plausible = { lib, pkgs, config, ... }: {
    environment.systemPackages = with pkgs; [
      plausible tmux
      (writeShellScriptBin "plausible-run" ''
        path=$(dirname $(dirname $(readlink -f $(which plausible))))
        echo $path
        "$path/createdb.sh"
        "$path/migrate.sh"
        "$path/init-admin.sh"
        plausible start
      '')
    ];
    services.postgresql = {
      enable = true;
      authentication = ''
        host all all 0.0.0.0/0 trust
      '';
      initialScript = "${pkgs.writeText "foo" ''
        CREATE ROLE plausible WITH LOGIN PASSWORD 'plausible';
        CREATE DATABASE plausible WITH OWNER plausible;
        ALTER USER plausible WITH SUPERUSER;
        ALTER USER plausible WITH CREATEDB;
      ''}";
    };
    services.clickhouse = {
      enable = true;
    };
    environment.sessionVariables = {
      "DATABASE_URL" = "postgres://plausible:plausible@localhost:5432/plausible";
      "CLICKHOUSE_DATABASE_URL" = "http://localhost:8123/default";
      "RELEASE_TMP" = "/root/foobar";
    };
    networking.firewall.allowedTCPPorts = [ 8000 ];
  };
}
