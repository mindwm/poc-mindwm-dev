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
          { category = "MindWM"; package = cell.apps.runTmuxSession; }
          { category = "MindWM"; package = cell.apps.load_all_images; }
          { category = "MindWM"; package = cell.apps.compose_back; }
          { category = "MindWM"; package = cell.apps.current_subject; }

          { category = "MindWM"; package = cell.apps.nats_back; }
          { category = "MindWM"; package = cell.apps.vector_back; }
          { category = "MindWM"; package = cell.apps.nats_client; }
          { category = "MindWM"; package = cell.apps.vector_client; }

          { category = "MindWM"; package = cell.apps.tmux; }
        ] ++ (
          map (p: { category = "tools"; package = p; }) (with inputs.nixpkgs; [
            netcat-openbsd
            natscli
            vim gnused bat jq yq ripgrep fd eza
            tmux
            (python311.withPackages (ps: with ps; [
              nats-py pyte ipython python-decouple
              (libtmux.overrideAttrs (f: p: rec {
                  version = "0.32.0";
                  src = fetchFromGitHub {
                    owner = "tmux-python";
                    repo = p.pname;
                    rev = "refs/tags/v${version}";
                    hash = "sha256-8x98yYgA8dY9btFePDTB61gsRZeOVpnErkgJRVlYYFY=";
                  };
                  postPatch = ''
                    sed -i '/addopts/d' pyproject.toml
                  '';
              }))
            ]))
          ]));
    };
  }
