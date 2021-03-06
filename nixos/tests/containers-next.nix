# FIXME the test is still kinda flaky. However the same approach works fine
# in my Hetzner playground, so I guess the culprit is hidden somewhere here.

import ./make-test-python.nix ({ pkgs, lib, ... }: {
  name = "container-tests";
  meta = with pkgs.stdenv.lib.maintainers; {
    maintainers = [ ma27 ];
  };

  # Just an arbitrary `client'-machine to test the public endpoints
  # of containers hosted on a different server.
  nodes.client = { pkgs, ... }: {
    virtualisation.vlans = [ 1 ];
    boot.consoleLogLevel = 7;
    environment.systemPackages = [ pkgs.tcpdump pkgs.tmux ];
    systemd.network.networks."10-eth1" = {
      matchConfig.Name = "eth1";
      networkConfig = {
        IPForward = "yes";
        IPv6AcceptRA = "yes";
      };
      address = [ "fd23::1/64" ];
      routes = [
        { routeConfig.Destination = "fd24::1/64"; }
      ];
    };
    networking = {
      useNetworkd = true;
      useDHCP = false;
      interfaces.eth0.useDHCP = true;
    };
  };

  # Demo server which hosts nspawn machines.
  nodes.server = { pkgs, lib, ... }: {
    virtualisation.vlans = [ 1 ];
    systemd.services.systemd-networkd.environment.SYSTEMD_LOG_LEVEL = "debug";
    boot.consoleLogLevel = 7;

    # Several nspawn machines to test different things:
    # * `container0': assign ULA IPv6 address (to demonstrate public addrs) and
    #   let nginx listen on it.
    # * `container1': mount needed paths into the VM rather than sharing a full store.
    nixos.containers.instances = {
      container0 = {
        network.v6.static = {
          containerPool = [ "fd24::2/64" ];
        };
        network.v6.addrPool = lib.mkForce [];
        config = { pkgs, ... }: {
          networking.firewall.allowedTCPPorts = [ 80 ];
          systemd.services.systemd-networkd.environment.SYSTEMD_LOG_LEVEL = "debug";
          services.nginx = {
            enable = true;
            virtualHosts."localhost" = {
              listen = [
                { addr = "[fd24::2]"; port = 80; ssl = false; }
              ];
            };
          };
        };
      };
      container1 = {
        sharedNix = false;
        nixpkgs = ../..;
        zone = "foo";
        config = { pkgs, ... }: {
          environment.systemPackages = [ pkgs.hello ];
          systemd.services.systemd-networkd.environment.SYSTEMD_LOG_LEVEL = "debug";
        };
      };
    };

    nixos.containers.zones = {
      foo = {};
    };

    systemd.network.networks."10-eth1" = {
      matchConfig.Name = "eth1";
      address = [ "fd24::1/64" ];
      networkConfig.IPv6ProxyNDP = "yes";
      networkConfig = {
        IPForward = "yes";
        IPv6AcceptRA = "yes";
      };
      routes = [
        { routeConfig.Destination = "fd23::1/64"; }
      ];
    };

    # FIXME probably provide a nicer API here
    systemd.network.networks."20-ve-container0".routes = [
      { routeConfig.Destination = "fd24::2"; }
    ];

    networking = {
      useNetworkd = true;
      useDHCP = false;
      interfaces.eth0.useDHCP = true;
    };

    # `server' is supposed to use `fd24::1/64`. However the test network in QEMU
    # doesn't take care of neighbour resolution via NDP. To work around this, `server'
    # proxies NDP traffic of container IPs.
    services.ndppd = {
      enable = true;
      proxies.eth1.rules."fd24::2/128" = {};
    };

    programs.mtr.enable = true;
    environment.systemPackages = [ pkgs.tcpdump pkgs.tmux ];

    # Needed to make sure that the DHCPServer of `systemd-networkd' properly works and
    # can assign IPv4 addresses to containers.
    time.timeZone = "Europe/Berlin";
    networking.firewall.allowedUDPPorts = [ 67 68 546 547 ];
  };

  testScript = ''
    start_all()

    server.wait_for_unit("machines.target")
    server.wait_for_unit("multi-user.target")
    server.wait_for_unit("network-online.target")

    client.wait_for_unit("network-online.target")
    client.wait_for_unit("multi-user.target")

    server.wait_for_unit("systemd-nspawn@container0")
    server.wait_for_unit("systemd-networkd-wait-online.service")
    client.wait_for_unit("systemd-networkd-wait-online.service")

    server.execute("ping fd24::1 -c3 >&2")
    server.execute("ping fd24::2 -c3 >&2 || true")
    client.execute("ping fd24::1 -c3 >&2 || true")
    server.wait_until_succeeds("ping -4 container0 -c3 >&2")
    server.wait_until_succeeds("ping -6 container0 -c3 >&2")

    server.wait_until_succeeds("curl -sSf 'http://[fd24::2]' | grep -q 'Welcome to nginx'")

    client.wait_until_succeeds("ping fd24::2 -c3 >&2")
    client.succeed("curl -sSf 'http://[fd24::2]' | grep -q 'Welcome to nginx'")

    server.succeed("machinectl poweroff container0")
    server.succeed("machinectl poweroff container1")

    server.wait_until_unit_stops("systemd-nspawn@container0")
    server.wait_until_unit_stops("systemd-nspawn@container1")

    client.shutdown()
    server.shutdown()
  '';
})
