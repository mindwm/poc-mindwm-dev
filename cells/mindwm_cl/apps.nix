{
  inputs,
  cell
}: let
  inherit (inputs) nixpkgs std;
  inherit (std.lib.ops) mkOperable;
  inherit (cell) configs;

  l = nixpkgs.lib // builtins;

  system = inputs.nixpkgs.system;
  unstable = inputs.unstable.legacyPackages.${system};

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

in rec {
# backend services
  nats_back = mkOperable rec {
    package = cell.packages.nats;
    name = "nats-back";
    runtimeInputs = [ ];
    runtimeScript = ''
      ${mkShellEnvVars cell.configs.backend.nats.envVars}
      export MINDWM_BACK_NATS_LISTEN="''${MINDWM_BACK_NATS_BIND}:''${MINDWM_BACK_NATS_PORT}"
      exec ${package}/bin/nats-server -c "${backend.config.nats}" "$@"
    '';
  };

  vector_back = mkOperable rec {
    package = cell.packages.vector;
    name = "vector-back";
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
    name = "nats-client";
    runtimeInputs = [ ];
#exec ${package}/bin/nats-server --user root --pass r00tpass -js "$@"
    runtimeScript = ''
      ${mkShellEnvVars cell.configs.client.nats.envVars}
      export MINDWM_CLIENT_NATS_LISTEN="''${MINDWM_CLIENT_NATS_BIND}:''${MINDWM_CLIENT_NATS_PORT}"
      exec ${package}/bin/nats-server -c "${client.config.nats}" "$@"
    '';
  };

  vector_client = mkOperable rec {
    package = cell.packages.vector;
    name = "vector-client";
    runtimeInputs = [ inputs.nixpkgs.coreutils ];
    runtimeScript = ''
      ${mkShellEnvVars cell.configs.client.vector.envVars}
      export MINDWM_CLIENT_VECTOR_UDP_ADDR="''${MINDWM_CLIENT_VECTOR_UDP_BIND}:''${MINDWM_CLIENT_VECTOR_UDP_PORT}"
      export MINDWM_CLIENT_NATS_ADDR="nats://''${MINDWM_CLIENT_NATS_HOST}:''${MINDWM_CLIENT_NATS_PORT}"

      echo "Starting Vector with ''${VECTOR_CONFIG} as config..."
      mkdir -p "$HOME/.local/mindwm/vector"

      function validate_and_run() {
        ${package}/bin/vector validate && \
        ${package}/bin/vector "$@"
      }
      printf "trying to connect to endpoints."
      until validate_and_run "$@"; do
        sleep 1
        printf "."
      done
    '';
  };

  tmux = mkOperable rec {
    package = inputs.nixpkgs.tmux;
    runtimeScript = ''
      exec ${package}/bin/tmux -f "${client.config.tmux}" "$@"
    '';
  };

  runTmuxSession = mkOperable rec {
    package = { name = "mindwm-demo"; };
#package = inputs.nixpkgs.tmuxinator;
    runtimeInputs = (with nixpkgs; [
      coreutils procps iproute2 nettools which
      less
      netcat-openbsd
      jq yq
      bat fd ripgrep eza
      cowsay
      cowsay
    ]) ++ (with unstable; [
      natscli
    ]) ++ (with cell.packages; [
      tmux
      tmuxinator
    ]) ++ [
      nats_client
      vector_client
      current_subject
    ];
    runtimeShell = nixpkgs.bashInteractive;
    runtimeScript = ''
      # FIX: don't know why but tmux is not in PATH by default
      PATH="$PATH:${cell.packages.tmux}/bin"
      exec tmuxinator start -n MindWM -p "${client.config.tmuxinator}" "$@"
    '';
  };

#      PATH="$PATH:${cell.packages.mindwm_current_subject}/bin"

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

  current_subject = mkOperable rec {
    package = cell.packages.mindwm_current_subject;
    runtimeScript = "${package}/bin/get_current_subject.sh";
#    package = { name = "current-subject"; };
#    runtimeScript = (builtins.readFile ./scripts/get_current_subject.sh);
  };

  asciinema = mkOperable rec {
    package = cell.packages.asciinema;
    runtimeScript = ''${package}/bin/asciinema rec --stdin --append "''${MINDWM_ASCIINEMA_REC_PIPE}"'';
  };

  github_runner = mkOperable rec {
    package = unstable.github-runner;
    runtimeScript = ''
      exec ${package}/bin/Runner.Listener "$@"
    '';
    runtimeInputs = (with nixpkgs; [
      coreutils procps iproute2 nettools iputils which less
      bashInteractive gnugrep curl
      gnumake gitMinimal gnutar gzip gnused
    ]) ++ (with unstable; [
      kubernetes-helm argocd
    ]);
  };
}
