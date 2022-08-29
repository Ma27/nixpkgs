{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.rust-motd;
  format = pkgs.formats.toml { };
in {
  options.programs.rust-motd = {
    enable = mkEnableOption "rust-motd";
    enableMotdInSSHD = mkOption {
      default = true;
      type = types.bool;
      description = ''
        Whether to let <package>openssh</package> print the
        result when entering a new <literal>ssh</literal>-session.
        By default either nothing or a static file defined via
        <xref linkend="opt-users.motd" /> is printed. Because of that,
        the latter option is incompatible with this module.
      '';
    };
    refreshInterval = mkOption {
      default = "*:0/5";
      type = types.str;
      description = ''
        Interval in which the <citerefentry><refentrytitle>motd</refentrytitle>
        <manvolnum>5</manvolnum></citerefentry> file is refreshed.
        For possible formats, please refer to <citerefentry><refentrytitle>systemd.time
        </refentrytitle><manvolnum>7</manvolnum></citerefentry>.
      '';
    };
    settings = mkOption {
      type = types.submodule {
        freeformType = format.type;
      };
      description = ''
        Settings on what to generate. Please read the
        <link xlink:href="https://github.com/rust-motd/rust-motd/blob/main/README.md#configuration">
        upstream documentation</link> for further information.
      '';
    };
  };
  config = mkIf cfg.enable {
    assertions = [
      { assertion = config.users.motd == null;
        message = ''
          `programs.rust-motd` is incompatible with `users.motd`!
        '';
      }
    ];
    systemd.services.rust-motd = {
      path = with pkgs; [ bash ];
      documentation = [ "https://github.com/rust-motd/rust-motd/blob/v${pkgs.rust-motd.version}/README.md" ];
      description = "motd generator";
      serviceConfig = {
        ExecStart = "${pkgs.writeShellScript "update-motd" ''
          ${pkgs.rust-motd}/bin/rust-motd ${format.generate "motd.conf" cfg.settings} > motd
        ''}";
        CapabilityBoundingSet = [ "" ];
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectKernelTunables = true;
        ProtectSystem = "full";
        StateDirectory = "rust-motd";
        RestrictAddressFamilies = "none";
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        RemoveIPC = true;
        WorkingDirectory = "/var/lib/rust-motd";
      };
    };
    systemd.timers.rust-motd = {
      wantedBy = [ "timers.target" ];
      timerConfig.OnCalendar = cfg.refreshInterval;
    };
    security.pam.services.sshd.text = mkIf cfg.enableMotdInSSHD (mkDefault (mkAfter ''
      session optional ${pkgs.pam}/lib/security/pam_motd.so motd=/var/lib/rust-motd/motd
    ''));
    services.openssh.extraConfig = mkIf (cfg.settings ? last_login && cfg.settings.last_login != {}) ''
      PrintLastLog no
    '';
  };
  meta.maintainers = with maintainers; [ ma27 ];
}
