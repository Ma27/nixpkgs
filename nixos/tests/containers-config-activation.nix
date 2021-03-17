import ./make-test-python.nix ({ pkgs, lib, ... }: let
  configchange = { ... }: {
    networking = {
      useDHCP = false;
      useNetworkd = true;
      interfaces.eth0.useDHCP = true;
    };
    nixos.containers.instances.test = {
      network.v4.static.containerPool = [ "10.231.136.2/24" ];
      network.v4.static.hostAddresses = [ "10.231.136.1/24" ];
      activation.strategy = "reload";
      config = {
        services.nginx = {
          enable = true;
          virtualHosts."localhost" = {
            listen = [
              { addr = "10.231.136.2"; port = 80; ssl = false; }
            ];
          };
        };
        networking.firewall.allowedTCPPorts = [ 80 ];
      };
    };
    nixos.containers.instances.test2 = {
      sharedNix = false;
      network.v4.static.containerPool = [ "10.231.137.2/24" "fd23::2/64" ];
      network.v4.static.hostAddresses = [ "10.231.137.1/24" "fd23::1/64" ];
      activation.strategy = "restart";
      config = { pkgs, ... }: {
        environment.systemPackages = with pkgs; [ hello ];
      };
    };
    # TODO ipv6 test here!
    nixos.containers.instances.test3 = {
      network.v4.static.containerPool = [ "10.231.138.2/24" ];
      network.v4.static.hostAddresses = [ "10.231.138.1/24" ];
      activation.strategy = "dynamic";
    };
    systemd.nspawn.test3.filesConfig.BindReadOnly = [
      "/etc:/tmp"
    ];
  };
in {
  name = "container-tests";
  meta = with pkgs.stdenv.lib.maintainers; {
    maintainers = [ ma27 ];
  };

  nodes = {
    base = { ... }: {
      networking = {
        useDHCP = false;
        useNetworkd = true;
        interfaces.eth0.useDHCP = true;
      };
      nixos.containers.instances.test = {
        network.v4.static.containerPool = [ "10.231.136.2/24" ];
        network.v4.static.hostAddresses = [ "10.231.136.1/24" ];
        activation.strategy = "reload";
      };
      nixos.containers.instances.test2 = {
        sharedNix = false;
        network.v4.static.containerPool = [ "10.231.137.2/24" ];
        network.v4.static.hostAddresses = [ "10.231.137.1/24" ];
        activation.strategy = "restart";
      };
      nixos.containers.instances.test3 = {
        network.v4.static.containerPool = [ "10.231.138.2/24" ];
        network.v4.static.hostAddresses = [ "10.231.138.1/24" ];
        activation.strategy = "dynamic";
      };
    };
    inherit configchange;
    configchange2 = { lib, ... }: {
      imports = [
        configchange
      ];
      nixos.containers.instances.test3.config = { pkgs, ... }: {
        environment.systemPackages = [ pkgs.hello ];
      };
    };
    configchange3 = { lib, ... }: {
      imports = [ configchange ];
    };
    stop = { lib, ... }: {
      networking = {
        useDHCP = false;
        useNetworkd = true;
        interfaces.eth0.useDHCP = true;
      };
      nixos.containers.instances.test4 = {
        network.v4.static.containerPool = [ "10.231.139.2/24" ];
        network.v4.static.hostAddresses = [ "10.231.139.1/24" ];
        activation.strategy = "dynamic";
      };
      nixos.containers.instances.test5 = {
        network.v4.static.containerPool = [ "10.231.140.2/24" ];
        network.v4.static.hostAddresses = [ "10.231.140.1/24" ];
        activation.strategy = "reload";
      };
    };
  };

  testScript = { nodes, ... }: let
    change = nodes.configchange.config.system.build.toplevel;
    change2 = nodes.configchange2.config.system.build.toplevel;
    change3 = nodes.configchange2.config.system.build.toplevel;
    stop = nodes.stop.config.system.build.toplevel;
  in ''
    base.start()
    base.wait_for_unit("network.target")
    assert "test" in base.succeed("machinectl")
    base.wait_until_succeeds("ping -c3 10.231.136.1 >&2")
    base.wait_until_succeeds("ping -c3 10.231.136.2 >&2")
    base.wait_until_succeeds("ping -c3 10.231.137.2 >&2")
    base.wait_until_succeeds("ping -c3 10.231.138.2 >&2")

    with subtest("Base state"):
        # No bind-mounts, nginx not here yet
        base.fail(
            "systemd-run -M test3 --pty --quiet -- /bin/sh --login -c 'test -e /tmp/systemd'"
        )

        base.fail("systemd-run -M test2 --pty --quiet -- /bin/sh --login -c 'hello'")
        base.fail("curl 10.231.136.2 -sSf --connect-timeout 10")

        base.fail("ping -c3 fd23::1 >&2")

        out = base.succeed(
            "${change}/bin/switch-to-configuration test 2>&1 | tee /dev/stderr"
        )

        # Machine `test' requires a reload
        assert "reloading the following units: systemd-nspawn@test.service" in out
        assert (
            "restarting the following units: systemd-nspawn@test.service, systemd-nspawn@test2.service"
            not in out
        )

        # Machine `test3' has new bind mounts and thus requires a restart
        assert (
            "test3.service"
            in [s for s in out.split("\n") if "restarting the following" in s][0]
        )

    with subtest("First change"):
        base.wait_until_succeeds("ping -c3 10.231.136.2 >&2")
        base.wait_until_succeeds("ping -c3 10.231.137.2 >&2")
        base.wait_until_succeeds("ping -c3 10.231.138.2 >&2")

        base.succeed("ping -c3 fd23::1 >&2")
        base.wait_until_succeeds("ping -c3 fd23::2 >&2")
        base.execute(
            "curl 10.231.136.2 -sSf --connect-timeout 10 | grep 'Welcome to nginx'"
        )

        base.succeed(
            "systemd-run -M test3 --pty --quiet -- /bin/sh --login -c 'ls -lah /tmp/'"
        )
        base.succeed(
            "systemd-run -M test3 --pty --quiet -- /bin/sh --login -c 'test -e /tmp/systemd'"
        )
        base.succeed("systemd-run -M test2 --pty --quiet -- /bin/sh --login -c 'hello'")
        base.fail("systemd-run -M test3 --pty --quiet -- /bin/sh --login -c 'hello'")

        out = base.succeed(
            "${change2}/bin/switch-to-configuration test 2>&1 | tee /dev/stderr"
        )

        assert "reloading the following units: systemd-nspawn@test3.service" in out

    with subtest("Second change"):
        # No wait here since those two shouldn't be touched here
        base.succeed("ping -c3 10.231.136.2 >&2")
        base.succeed("ping -c3 10.231.137.2 >&2")
        base.succeed("systemd-run -M test3 --pty --quiet -- /bin/sh --login -c 'hello'")
        base.fail("ping -c3 10.231.139.2 >&2")
        base.fail("ping -c3 10.231.140.2 >&2")

    with subtest("Start stopped container"):
        base.succeed("machinectl poweroff test3")
        base.wait_until_unit_stops("systemd-nspawn@test3")

        out = base.succeed(
            "${change3}/bin/switch-to-configuration test 2>&1 | tee /dev/stderr"
        )

        base.wait_until_succeeds("ping -c3 10.231.138.2 >&2")

    with subtest("Container removal behavior"):
        out = base.succeed(
            "${stop}/bin/switch-to-configuration test 2>&1 | tee /dev/stderr"
        )

        stopl = [s for s in out.split("\n") if "stopping the following" in s][0]
        for i in ["test", "test2.service", "test3.service"]:
            assert i in stopl

        base.fail("ping -c3 10.231.136.2 >&2")
        base.fail("ping -c3 10.231.137.2 >&2")
        base.fail("ping -c3 10.231.138.2 >&2")

        base.succeed("ping -c3 10.231.139.2 >&2")
        base.succeed("ping -c3 10.231.140.2 >&2")

    base.shutdown()
  '';
})
