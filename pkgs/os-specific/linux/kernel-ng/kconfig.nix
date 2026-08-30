{
  lib,
  rokc,
  runCommand,
  jq,
}:

{
  configAccessor = {
    _type = "rokc";

    mkAssertions =
      config: conditions:
      let
        assertions =
          lib.foldl
            (
              acc:
              { what, name }:
              acc
              // {
                ${what} = acc.${what} ++ [
                  name
                ];
              }
            )
            {
              set = [ ];
              enabled = [ ];
              disabled = [ ];
              module = [ ];
              yes = [ ];
              no = [ ];
            }
            conditions;
      in
      runCommand "kconfig-checks"
        {
          nativeBuildInputs = [
            rokc
            jq
          ];
          __structuredAttrs = true;
          inherit assertions;
        }
        ''
          rokcnix assert -c ${config} -a <(jq -r .assertions < "$NIX_ATTRS_JSON_FILE")
          touch $out
        '';

    isSet = name: {
      what = "set";
      inherit name;
    };
    isYes = name: {
      what = "yes";
      inherit name;
    };
    isNo = name: {
      what = "no";
      inherit name;
    };
    isModule = name: {
      what = "module";
      inherit name;
    };
    isEnabled = name: {
      what = "enabled";
      inherit name;
    };
    isDisabled = name: {
      what = "disabled";
      inherit name;
    };
  };

  mkKConfigEvaluator =
    inputFile: extras:
    lib.fix (self: {
      inherit inputFile;
      inherit (builtins.fromJSON (builtins.readFile inputFile)) declarations;

      evalOverrides = lib.evalModules {
        modules = [
          # FIXME
          # this needs some documentation clarifying that this is for non-invasive
          # overrides only. E.g. MODULES=n should be done via rokc.
          # Maybe some rules-of-thumb or quick tests might be good.
          ({ config, ... }: {
            options = {
              defaults = lib.mkOption {
                type = lib.types.attrsOf lib.types.raw;
                readOnly = true;
                default = self.declarations;
                defaultText = "<ROKC declarations>";
              };
              custom = lib.mkOption {
                type = lib.types.attrsOf lib.types.raw;
                default = { };
              };
              outFile = lib.mkOption {
                type = lib.types.path;
                readOnly = true;
                defaultText = "<file with all overrides>";
                default = builtins.toFile "overrides.json" (builtins.toJSON config.custom);
              };
            };
          })
          extras
        ];
      };
    });
}
