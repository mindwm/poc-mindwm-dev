lib: {
  pkgs
, config
}: let
  n = "omg";
in {
  name = "MindWM";
  root = "./";
  tmux_options = "-f ${config.tmux.config}";
  startup_window = "shell";
  startup_pane = 0;
  windows = [
    { mw = {
        layout = "main-horizontal";
        panes = [
          "until operable-nats-client; do sleep 1; done"
          "until operable-vector-client; do sleep 1; done"
        ];
      };
    }
    { shell = {
        layout = "main-horizontal";
        panes = [
          ''
            nats_host="''${MINDWM_NATS_CLIENT_HOST:-${config.client.nats.host}}"
            nats_port="''${MINDWM_NATS_CLIENT_PORT:-${toString config.client.nats.port}}"
            nats_user="''${MINDWM_NATS_CLIENT_USER:-${config.client.nats.creds.user}}"
            nats_pass="''${MINDWM_NATS_CLIENT_PASS:-${config.client.nats.creds.pass}}"
            ${pkgs.cowsay}/bin/cowsay 'It`s demo time'
            shell_pane=$(tmux split-window -b -p80 -P -F '#{pane_id}')
            tmux send-keys -t "''${shell_pane}" "tmux pipe-pane -IO 'nc -u ${config.client.vector.udp.host} ${config.client.vector.udp.port}'" Enter
            tmux send-keys -t "''${shell_pane}" "cowsay Start your journey here" Enter
            subject=''$(MINDWM_TMUX_TARGET_PANE="''${shell_pane}" operable-current-subject)
            printf "trying to connect to NATS topic: "
            until nats sub -s "nats://$nats_user:$nats_pass@$nats_host:$nats_port" "$subject"; do
              printf "."
              sleep 1
            done
          ''
        ];
      };
    }
  ];
}
