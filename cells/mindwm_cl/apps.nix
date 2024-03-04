{
  inputs,
  cell
}: let
  inherit (inputs) nixpkgs std;
  inherit (std.lib.ops) mkOperable;

  l = nixpkgs.lib // builtins;
  vector.config = cell.configs.vector.configFile;
  nats.config = cell.configs.nats.configFile;
  tmux.config = cell.configs.tmux.configFile;
  tmuxinator.config = cell.configs.tmuxinator.configFile;

in {
  vector = mkOperable rec {
    package = cell.packages.vector;
    runtimeInputs = [ inputs.nixpkgs.coreutils ];
    runtimeScript = ''
      mkdir -p "$HOME/.local/mindwm/vector"
      exec ${package}/bin/vector validate --config-toml="${vector.config}" && \
      exec ${package}/bin/vector --config-toml="${vector.config}" "$@"
    '';
#    meta.mainProgram = "vector";
  };
  nats = mkOperable rec {
    package = cell.packages.nats;
    runtimeInputs = [ ];
#exec ${package}/bin/nats-server --user root --pass r00tpass -js "$@"
    runtimeScript = ''
      exec ${package}/bin/nats-server -c "${nats.config}" "$@"
    '';
  };
  tmux = mkOperable rec {
    package = inputs.nixpkgs.tmux;
    runtimeScript = ''
      exec ${package}/bin/tmux -f "${tmux.config}" "$@"
    '';
  };
  runTmuxSession = mkOperable rec {
    package = inputs.nixpkgs.tmuxinator;
    runtimeScript = ''
      exec ${package}/bin/tmuxinator start -n MindWM -p "${tmuxinator.config}" "$@"
    '';
  };

  mwm_join = mkOperable rec {
    package = inputs.nixpkgs.cowsay;
    runtimeScript = ''
      exec ${package}/bin/cowsay "Are you ready to join to the MindWM?" "$@"
    '';
  };
}
