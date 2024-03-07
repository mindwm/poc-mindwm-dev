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

  mkShellEnvVars = l.foldlAttrs (acc: name: val: ''
    ${acc}
    export ${name}="''${${name}:-${val}}"'') "";

in {
# backend services
  nats_back = mkOperable rec {
    package = cell.packages.nats;
    runtimeInputs = [ ];
    runtimeScript = ''
      ${mkShellEnvVars cell.configs.backend.nats.envVars}
      export MINDWM_BACK_NATS_LISTEN="''${MINDWM_BACK_NATS_BIND}:''${MINDWM_BACK_NATS_PORT}"
      exec ${package}/bin/nats-server -c "${backend.config.nats}" "$@"
    '';
  };

  vector_back = mkOperable rec {
    package = cell.packages.vector;
    runtimeInputs = [ inputs.nixpkgs.coreutils ];
    runtimeScript = ''
      ${mkShellEnvVars cell.configs.backend.vector.envVars}
      export MINDWM_BACK_VECTOR_ADDR="''${MINDWM_BACK_VECTOR_BIND}:''${MINDWM_BACK_VECTOR_PORT}"
      export MINDWM_BACK_NATS_ADDR="nats://''${MINDWM_BACK_NATS_HOST}:''${MINDWM_BACK_NATS_PORT}"
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
      ${mkShellEnvVars cell.configs.client.vector.envVars}
      export MINDWM_CLIENT_VECTOR_UDP_ADDR="''${MINDWM_CLIENT_VECTOR_UDP_BIND}:''${MINDWM_CLIENT_VECTOR_UDP_PORT}"
      export MINDWM_CLIENT_NATS_FEEDBACK_ADDR="nats://''${MINDWM_CLIENT_NATS_FEEDBACK_HOST}:''${MINDWM_CLIENT_NATS_FEEDBACK_PORT}"

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

  load_all_images = mkOperable rec {
    package = { name = "load-oci_images"; };
    runtimeScript = ''
      std list | rg '//.*/containers.*:load' -o | xargs -I% std %
    '';
  };

  compose_back = mkOperable rec {
    package = { name = "run-compose-back"; };
    runtimeScript = ''
      std //mindwm_cl/configs/compose_back:populate
      docker compose -f ./compose-back.yaml up
    '';
  };

  mwm_join = mkOperable rec {
    package = inputs.nixpkgs.cowsay;
    runtimeScript = ''
      exec ${package}/bin/cowsay "Are you ready to join to the MindWM?" "$@"
    '';
  };
}
