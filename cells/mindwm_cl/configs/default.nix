{
  inputs,
  cell
}:
let
  inherit (inputs.nixpkgs) lib;
  inherit (inputs.std.lib) dev;

  client = rec {
    vector.udp = {
      bind = "0.0.0.0";
      host = "127.0.0.1";
      port = "32020";
    };
    vector.envVars = {
      VECTOR_CONFIG = cell.configs.vector_client.configFile;
      MINDWM_CLIENT_VECTOR_UDP_BIND = vector.udp.bind;
      MINDWM_CLIENT_VECTOR_UDP_PORT = (toString vector.udp.port);
      MINDWM_CLIENT_NATS_FEEDBACK_HOST = nats.feedback.host;
      MINDWM_CLIENT_NATS_FEEDBACK_PORT = (toString nats.feedback.port);
      MINDWM_CLIENT_NATS_FEEDBACK_USER = nats.feedback.creds.user;
      MINDWM_CLIENT_NATS_FEEDBACK_PASS = nats.feedback.creds.pass;
      MINDWM_CLIENT_NATS_FEEDBACK_SUBJECT = nats.feedback.subject;
      MINDWM_BACK_VECTOR_HOST = backend.vector.host;
      MINDWM_BACK_VECTOR_PORT = (toString backend.vector.port);
      MINDWM_CLIENT_SESSION_ID = "localDebugSession";
    };
    nats = {
      bind = "0.0.0.0";
      port = 32040;
      host = "127.0.0.1";
      subject = "mindwm.sessionID.feedback";
      creds = backend.nats.creds;
      envVars = {
        MINDWM_CLIENT_NATS_BIND = nats.bind;
        MINDWM_CLIENT_NATS_PORT = (toString nats.port);
        MINDWM_CLIENT_NATS_ADMIN_USER = nats.creds.user;
        MINDWM_CLIENT_NATS_ADMIN_PASS = nats.creds.pass;
      };
    };
    nats.feedback = {
      host = backend.nats.host;
      port = backend.nats.port;
      subject = "clients.sessionID.feedback";
      creds = backend.nats.creds;
    };
  };
  backend = rec {
    vector = {
      bind = "0.0.0.0";
      port = 32030;
      host = "127.0.0.1";
      envVars = {
        VECTOR_CONFIG = cell.configs.vector_back.configFile;
        MINDWM_BACK_VECTOR_BIND = vector.bind;
        MINDWM_BACK_VECTOR_PORT = (toString vector.port);
        MINDWM_BACK_NATS_HOST = nats.host;
        MINDWM_BACK_NATS_PORT = (toString nats.port);
        MINDWM_BACK_NATS_USER = nats.creds.user;
        MINDWM_BACK_NATS_PASS = nats.creds.pass;
      };
    };
    nats = {
      bind = "0.0.0.0";
      port = 32040;
      host = "127.0.0.1";
      subject = "mindwm.sessionID.feedback";
      creds = {
        user = "root";
        pass = "r00tpass";
      };
      envVars = {
        MINDWM_BACK_NATS_BIND = nats.bind;
        MINDWM_BACK_NATS_PORT = (toString nats.port);
        MINDWM_BACK_NATS_ADMIN_USER = nats.creds.user;
        MINDWM_BACK_NATS_ADMIN_PASS = nats.creds.pass;
      };
    };
  };
in rec {
  inherit backend;
  inherit client;

  vector_back = (dev.mkNixago rec {
    template = (import ./templates/vector-back.nix) lib;
    output = "vector-back.toml";
    data = template {
    };
  });

  nats_back.configFile = inputs.nixpkgs.writeText "nats-server.conf" ''
    listen: $MINDWM_BACK_NATS_LISTEN
    jetstream {}
    authorization: {
      default_permissions = {
        publish = ">"
        subscribe = [">", ">"]
      }
      users = [
        { user: user, password: pass }
      ]
    }

    accounts: {
      SYS: {
        users: [
          { user: $MINDWM_BACK_NATS_ADMIN_USER,
            password: $MINDWM_BACK_NATS_ADMIN_PASS }
        ]
      }
    }

    system_account: SYS
  '';

  nats_client.configFile = inputs.nixpkgs.writeText "nats-client.conf" ''
    listen: $MINDWM_CLIENT_NATS_LISTEN
    jetstream {}
    authorization: {
      default_permissions = {
        publish = ">"
        subscribe = [">", ">"]
      }
      users = [
        { user: user, password: pass }
      ]
    }

    accounts: {
      SYS: {
        users: [
          { user: $MINDWM_CLIENT_NATS_ADMIN_USER,
            password: $MINDWM_CLIENT_NATS_ADMIN_PASS }
        ]
      }
    }

    system_account: SYS
  '';

  vector_client = (dev.mkNixago rec {
    template = (import ./templates/vector-client.nix) lib;
    output = "vector-client.toml";
    data = template {
    };
  });

  tmux.configFile =
    let
      safekill = inputs.nixpkgs.fetchFromGitHub {
        owner = "jlipps";
        repo = "tmux-safekill";
        rev = "a8e61d78e74d55a9f8dc3de31d7f537b3599f811";
        sha256 = "sha256-Iu3+KzYq7XiK6FFMmQev5g5+H5AS3ZO5P3N3N6iOYcY=";
      };
    in
    inputs.nixpkgs.writeText "tmux.conf" ''
      run-shell ${safekill}/safekill.tmux

      set -g pane-border-format "#{pane_index} #{pane_title}"
      set -g pane-border-status bottom
    '';

  tmuxinator = (dev.mkNixago rec {
      output = "tmuxinator.mindwm.client.yaml";
      template = (import ./templates/tmuxinator.mindwm.client.nix) lib;
      data = template {
        pkgs = inputs.nixpkgs;
        config = {
          inherit client;
          tmux.config = tmux.configFile;
        };
      };
  });

  compose_back = (dev.mkNixago rec {
    output = "compose-back.yaml";
    data = {
      networks.mindwm_lab = {};
      services = {
        nats_back = let port = (toString backend.nats.port); in {
          image = cell.containers.nats_back.image.name;
          # NOTE: environment vars can be ether a list of string or map
          # let's keep is as map
          # NOTE: but not for `docker compose` command:)
          environment = lib.mapAttrsToList (n: v: "${n}=${v}") backend.nats.envVars;
          #environment = backend.nats.envVars;
          ports = [ "${port}:${port}" ];
          networks = [ "mindwm_lab" ];
        };
        vector_back = let port = (toString backend.vector.port); in {
          image = cell.containers.vector_back.image.name;
          environment = lib.mapAttrsToList (n: v: "${n}=${v}") (lib.overrideExisting backend.vector.envVars
              { MINDWM_BACK_NATS_HOST = "nats_back";
              }
              );
          ports = [ "${port}:${port}" ];
          networks = [ "mindwm_lab" ];
          depends_on = [ "nats_back" ];
        };
      };
    };
  });

  compose_client = (dev.mkNixago rec {
    output = "compose-client.yaml";
    template = (import ./templates/docker-compose.nix) lib;
    data = template {
      services = {
        nats_client = {};
        vector_input = {};
        vector_feedback = {};
      };
    };
  });
}
