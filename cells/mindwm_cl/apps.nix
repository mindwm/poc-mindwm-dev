{
  inputs,
  cell
}: let
  inherit (inputs) nixpkgs std;
  inherit (std.lib.ops) mkOperable;

  l = nixpkgs.lib // builtins;

  backend.config = {
    nats = cell.configs.nats_back.configFile;
    vector = cell.configs.vector_back.configFile;
  };

  client.config = {
    nats = cell.configs.nats_client.configFile;
    vector = cell.configs.vector_client.configFile;
    tmux = cell.configs.tmux.configFile;
    tmuxinator = cell.configs.tmuxinator.configFile;
  };

in {
# backend services
  nats_back = mkOperable rec {
    package = cell.packages.nats;
    runtimeInputs = [ ];
    runtimeScript = ''
      exec ${package}/bin/nats-server -c "${backend.config.nats}" "$@"
    '';
  };

  vector_back = mkOperable rec {
    package = cell.packages.vector;
    runtimeInputs = [ inputs.nixpkgs.coreutils ];
    runtimeScript = ''
      export VECTOR_CONFIG="''${MINDWM_VECTOR_CONFIG:-${backend.config.vector}}"
      echo "Starting Vector with ''${VECTOR_CONFIG} as config..."
      mkdir -p "$HOME/.local/mindwm/vector"
      ${package}/bin/vector validate && \
      exec ${package}/bin/vector "$@"
    '';
  };

# client services
  nats_client = mkOperable rec {
    package = cell.packages.nats;
    runtimeInputs = [ ];
#exec ${package}/bin/nats-server --user root --pass r00tpass -js "$@"
    runtimeScript = ''
      exec ${package}/bin/nats-server -c "${client.config.nats}" "$@"
    '';
  };

  vector_client = mkOperable rec {
    package = cell.packages.vector;
    runtimeInputs = [ inputs.nixpkgs.coreutils ];
    runtimeScript = ''
      export VECTOR_CONFIG="''${MINDWM_VECTOR_CONFIG:-${backend.config.vector}}"
      echo "Starting Vector with ''${VECTOR_CONFIG} as config..."
      mkdir -p "$HOME/.local/mindwm/vector"
      ${package}/bin/vector validate && \
      exec ${package}/bin/vector "$@"
    '';
  };

  tmux = mkOperable rec {
    package = inputs.nixpkgs.tmux;
    runtimeScript = ''
      exec ${package}/bin/tmux -f "${client.config.tmux}" "$@"
    '';
  };

  runTmuxSession = mkOperable rec {
    package = inputs.nixpkgs.tmuxinator;
    runtimeScript = ''
      exec ${package}/bin/tmuxinator start -n MindWM -p "${client.config.tmuxinator}" "$@"
    '';
  };

  mwm_join = mkOperable rec {
    package = inputs.nixpkgs.cowsay;
    runtimeScript = ''
      exec ${package}/bin/cowsay "Are you ready to join to the MindWM?" "$@"
    '';
  };
}
