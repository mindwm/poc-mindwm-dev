{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  inherit (inputs.nixpkgs.lib) mapAttrs optionals;
  inherit (inputs.std) std;
  inherit (inputs.std.lib.dev) mkShell;
  inherit (cell) configs;
in
  mapAttrs (_: mkShell) rec {
    default = {...}: {
      name = "MindWM Client";
      imports = [ std.devshellProfiles.default ];
      commands =
        [
          { category = "operables"; package = cell.apps.vector; }

        ] ++ (
          map (p: { category = "tools"; package = p; }) (with inputs.nixpkgs; [
          ])
        );
    };
  }
