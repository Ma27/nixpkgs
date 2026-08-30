{
  lib,
  rokc,
  runCommand,
  jq,
}:

{
  configAccessor = lib.fix (self: {
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
  });
}
