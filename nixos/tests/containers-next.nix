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
    virtualisation.vlans = [ 1 2 ];
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
    systemd.network.networks."10-eth2" = {
      matchConfig.Name = "eth2";
      networkConfig = {
        DHCP = "yes";
      };
      address = [ "192.168.2.1/24" ];
      linkConfig.RequiredForOnline = "no";
    };
    networking = {
      useNetworkd = true;
      useDHCP = false;
      interfaces.eth0.useDHCP = true;
    };
  };

  # Test environment for MACVLAN functionality.
  #
  # Just as it was the case for the existing `nixos-container` implementation, I originally
  # planned an abstraction here as well, but decided against it for the following
  # reasons:
  # * systemd-networkd already provides well-designed abstractions for network configurations
  #   and a certain degree of declarativity.
  #
  # * in case of networkd we'd have to (1) create a host-interface for a MACVLAN (of course)
  #   and declare it as macvlan interface in the config of the *physical interface itself*.
  #   This means that we'd need a way to declare this in NixOS which turns out to be non-trivial
  #   since networkd only uses the first `.network` file (in lexical order) it can find
  #   so there's a risk that we'd invalidate other configurations with this.
  #
  # So to summarize, the abstractions I tried were leaky and IMHO useless. But now that we can
  # use systemd-nspawn itself for containers (and consider NixOS just a thin abstraction layer),
  # this isn't a big deal IMHO.
  nodes.macvlan = { pkgs, lib, ... }: {
    virtualisation.vlans = [ 2 ];
    boot.consoleLogLevel = 7;
    environment.systemPackages = [ pkgs.tcpdump pkgs.tmux ];
    systemd.network.networks."40-eth1" = {
      matchConfig.Name = "eth1";
      networkConfig.DHCP = lib.mkForce "yes";
      networkConfig.MACVLAN = "mv-eth1";
      linkConfig.RequiredForOnline = "no";
      address = lib.mkForce [];
      addresses = lib.mkForce [];
    };
    systemd.network.networks."20-mv-eth1" = {
      matchConfig.Name = "mv-eth1";
      networkConfig.IPForward = "yes";
      address = lib.mkForce [
        "192.168.2.2/24"
      ];
    };
    systemd.network.netdevs."20-mv-eth1" = {
      netdevConfig = {
        Name = "mv-eth1";
        Kind = "macvlan";
      };
      extraConfig = ''
        [MACVLAN]
        Mode=bridge
      '';
    };
    systemd.nspawn.vlandemo.networkConfig.MACVLAN = "eth1";
    networking = {
      useNetworkd = true;
      useDHCP = false;
      interfaces.eth0.useDHCP = true;
    };
    nixos.containers = {
      instances.vlandemo.config = {
        systemd.network = {
          networks."10-mv-eth1" = {
            matchConfig.Name = "mv-eth1";
            address = [ "192.168.2.5/24" ];
          };
        };
      };
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

    client.wait_for_unit("systemd-networkd-wait-online.service")
    macvlan.wait_for_unit("multi-user.target")

    server.wait_for_unit("systemd-nspawn@container0")
    server.wait_for_unit("systemd-networkd-wait-online.service")

    with subtest("Static networking"):
        server.execute("ping fd24::1 -c3 >&2")
        server.execute("ping fd24::2 -c3 >&2 || true")
        client.execute("ping fd24::1 -c3 >&2 || true")
        server.wait_until_succeeds("ping -4 container0 -c3 >&2")
        server.wait_until_succeeds("ping -6 container0 -c3 >&2")

        server.wait_until_succeeds(
            "curl -sSf 'http://[fd24::2]' | grep -q 'Welcome to nginx'"
        )

        client.wait_until_succeeds("ping fd24::2 -c3 >&2")
        client.succeed("curl -sSf 'http://[fd24::2]' | grep -q 'Welcome to nginx'")

    with subtest("MACVLANs"):
        macvlan.wait_until_succeeds("ping 192.168.2.2 -c3 >&2")
        macvlan.wait_until_succeeds("ping 192.168.2.5 -c3 >&2")
        client.wait_until_succeeds("ping 192.168.2.2 -c3 >&2")
        client.wait_until_succeeds("ping 192.168.2.5 -c3 >&2")

    server.succeed("machinectl poweroff container0")
    server.succeed("machinectl poweroff container1")

    server.wait_until_unit_stops("systemd-nspawn@container0")
    server.wait_until_unit_stops("systemd-nspawn@container1")

    macvlan.succeed("machinectl poweroff vlandemo")

    client.shutdown()
    server.shutdown()
    macvlan.shutdown()
  '';
})
