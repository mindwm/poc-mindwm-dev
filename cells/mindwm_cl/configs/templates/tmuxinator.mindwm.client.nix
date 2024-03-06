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
  startup_pane = 1;
  windows = [
    { shell = {
        layout = "main-horizontal";
        panes = [
          "clear\necho hi | ${pkgs.netcat}/bin/nc -u localhost ${toString config.feedback.port}"
          "clear\n${pkgs.netcat}/bin/nc -ul ${toString config.feedback.port}"
        ];
      };
    }
    { vector = {
        layout = "main-horizontal";
        panes = [
          "echo start client vector"
          "echo show client vector logs"
        ];
      };
    }
  ];
}
