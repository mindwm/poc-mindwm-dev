lib: {
}: 
{
  data_dir = ''''${HOME}/.local/mindwm/vector''; 
  sources.tmux_udp = {
    type = "socket";
    mode = "udp";
    decoding.codec = "bytes";
    address = ''''${MINDWM_CLIENT_VECTOR_UDP_BIND}:''${MINDWM_CLIENT_VECTOR_UDP_PORT}'';
  };
  sources.feedback = {
    type = "nats";
    connection_name = "hostname-client-vector";
    subject = ''''${MINDWM_CLIENT_NATS_FEEDBACK_SUBJECT}'';
    url = ''nats://''${MINDWM_CLIENT_NATS_FEEDBACK_HOST}:''${MINDWM_CLIENT_NATS_FEEDBACK_PORT}'';
    auth.strategy = "user_password";
    auth.user_password = {
      user = ''''${MINDWM_CLIENT_NATS_FEEDBACK_USER}'';
      password = ''''${MINDWM_CLIENT_NATS_FEEDBACK_PASS}'';
    };
    decoding.codec = "json";
  };

  transforms.tmux_words = {
    type = "reduce";
    inputs = [ "tmux_udp" ];
    group_by = [ "sessionID" ];
    ends_when = ''
      .message == " " || .message == "\n" || .message == "\t"
    '';
    merge_strategies.message = "concat_raw";
  };

  sinks.mindwm_vector = {
    type = "vector";
    inputs = [ "tmux_words" ];
    address = ''nats://''${MINDWM_BACK_VECTOR_HOST}:''${MINDWM_BACK_VECTOR_PORT}'';
    version = "2";
    acknowledgements.enabled = false;
  };

  sinks.feedback_to_console = {
    type = "console";
    inputs = [ "feedback" ];
    encoding.codec = "text";
  };

  sinks.debug = {
    type = "console";
    inputs = [ "tmux_udp" ];
    encoding.codec = "raw_message";
  };
}
