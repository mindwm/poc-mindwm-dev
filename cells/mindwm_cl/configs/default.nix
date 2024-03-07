{
  inputs,
  cell
}:
let
  inherit (inputs.nixpkgs) lib;
  inherit (inputs.std.lib) dev;

  client = {
    vector.udp = {
      bind = "127.0.0.1";
      port = "32020";
    };
    nats.feedback = {
      host = backend.nats.host;
      port = backend.nats.port;
      subject = "clients.sessionID.feedback";
      creds = backend.nats.creds;
    };
  };
  backend = {
    vector = {
      bind = "0.0.0.0";
      port = 32030;
      host = "127.0.0.1";
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
          tmux.config = tmux.configFile;
          feedback.port = 30009;
        };
      };
  });
}
