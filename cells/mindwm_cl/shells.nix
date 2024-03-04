{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  inherit (inputs.nixpkgs.lib) mapAttrs optionals;
  inherit (inputs.std) std;
  inherit (inputs.std.lib.dev) mkShell;
in
  mapAttrs (_: mkShell) rec {
    default = {...}: {
      name = "MindWM Client";
      imports = [ std.devshellProfiles.default ];
      commands =
        [
          { category = "MindWM";
            package = cell.apps.vector;
            #description = "Local vector instance to communicate with a MindWM backend";
          }
          { category = "MindWM";
            package = cell.apps.runTmuxSession;
          }
        ] ++ (
          map (p: { category = "tools"; package = p; }) (with inputs.nixpkgs; [
            tmux
          ])
        );
    };
  }
