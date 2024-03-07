{
  inputs,
  cell
}: let
  inherit (inputs) nixpkgs std;
  inherit (std.lib.ops) mkOperable;
  inherit (cell) configs;

  l = nixpkgs.lib // builtins;

  backend.config = {
    nats = configs.nats_back.configFile;
    vector = configs.vector_back.configFile;
  };

  client.config = {
    nats = configs.nats_client.configFile;
    vector = configs.vector_client.configFile;
    tmux = configs.tmux.configFile;
    tmuxinator = configs.tmuxinator.configFile;
  };

in {
# backend services
  nats_back = mkOperable rec {
    package = cell.packages.nats;
    runtimeInputs = [ ];
    runtimeScript = ''
      export MINDWM_BACK_NATS_BIND="''${MINDWM_BACK_NATS_BIND:-${configs.backend.nats.bind}}"
      export MINDWM_BACK_NATS_PORT="''${MINDWM_BACK_NATS_PORT:-${toString configs.backend.nats.port}}"
      export MINDWM_BACK_NATS_LISTEN="''${MINDWM_BACK_NATS_BIND}:''${MINDWM_BACK_NATS_PORT}"
      export MINDWM_BACK_NATS_ADMIN_USER="''${MINDWM_BACK_NATS_ADMIN_USER:-${configs.backend.nats.creds.user}}"
      export MINDWM_BACK_NATS_ADMIN_PASS="''${MINDWM_BACK_NATS_ADMIN_PASS:-${configs.backend.nats.creds.pass}}"
      exec ${package}/bin/nats-server -c "${backend.config.nats}" "$@"
    '';
  };

  vector_back = mkOperable rec {
    package = cell.packages.vector;
    runtimeInputs = [ inputs.nixpkgs.coreutils ];
    runtimeScript = ''
      export VECTOR_CONFIG="''${MINDWM_VECTOR_CONFIG:-${backend.config.vector}}"

      export MINDWM_BACK_VECTOR_BIND="''${MINDWM_BACK_VECTOR_BIND:-${configs.backend.vector.bind}}"
      export MINDWM_BACK_VECTOR_PORT="''${MINDWM_BACK_VECTOR_PORT:-${toString configs.backend.vector.port}}"
      export MINDWM_BACK_VECTOR_ADDR="''${MINDWM_BACK_VECTOR_BIND}:''${MINDWM_BACK_VECTOR_PORT}"

      export MINDWM_BACK_NATS_HOST="''${MINDWM_BACK_NATS_HOST:-${configs.backend.nats.host}}"
      export MINDWM_BACK_NATS_PORT="''${MINDWM_BACK_NATS_PORT:-${toString configs.backend.nats.port}}"
      export MINDWM_BACK_NATS_ADDR="nats://''${MINDWM_BACK_NATS_HOST}:''${MINDWM_BACK_NATS_PORT}"
      export MINDWM_BACK_NATS_USER="''${MINDWM_BACK_NATS_USER:-${configs.backend.nats.creds.user}}"
      export MINDWM_BACK_NATS_PASS="''${MINDWM_BACK_NATS_PASS:-${configs.backend.nats.creds.pass}}"

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
      export VECTOR_CONFIG="''${MINDWM_VECTOR_CONFIG:-${client.config.vector}}"

      export MINDWM_CLIENT_VECTOR_UDP_BIND="''${MINDWM_CLIENT_VECTOR_UDP_BIND:-${configs.client.vector.udp.bind}}"
      export MINDWM_CLIENT_VECTOR_UDP_PORT="''${MINDWM_CLIENT_VECTOR_UDP_PORT:-${toString configs.client.vector.udp.port}}"
      export MINDWM_CLIENT_VECTOR_UDP_ADDR="''${MINDWM_CLIENT_VECTOR_UDP_BIND}:''${MINDWM_CLIENT_VECTOR_UDP_PORT}"

      export MINDWM_CLIENT_NATS_FEEDBACK_HOST="''${MINDWM_CLIENT_NATS_FEEDBACK_HOST:-${configs.client.nats.feedback.host}}"
      export MINDWM_CLIENT_NATS_FEEDBACK_PORT="''${MINDWM_CLIENT_NATS_FEEDBACK_PORT:-${toString configs.client.nats.feedback.port}}"
      export MINDWM_CLIENT_NATS_FEEDBACK_ADDR="nats://''${MINDWM_CLIENT_NATS_FEEDBACK_HOST}:''${MINDWM_CLIENT_NATS_FEEDBACK_PORT}"
      export MINDWM_CLIENT_NATS_FEEDBACK_USER="''${MINDWM_CLIENT_NATS_FEEDBACK_USER:-${configs.client.nats.feedback.creds.user}}"
      export MINDWM_CLIENT_NATS_FEEDBACK_PASS="''${MINDWM_CLIENT_NATS_FEEDBACK_PASS:-${configs.client.nats.feedback.creds.pass}}"
      export MINDWM_CLIENT_NATS_FEEDBACK_SUBJECT="''${MINDWM_CLIENT_NATS_FEEDBACK_SUBJECT:-${configs.client.nats.feedback.subject}}"

      export MINDWM_BACK_VECTOR_HOST="''${MINDWM_BACK_VECTOR_HOST:-${configs.backend.vector.host}}"
      export MINDWM_BACK_VECTOR_PORT="''${MINDWM_BACK_VECTOR_PORT:-${toString configs.backend.vector.port}}"

      export MINDWM_CLIENT_SESSION_ID="localDebugSession"

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
