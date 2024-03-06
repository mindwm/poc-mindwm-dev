lib: {
  nats
, vector
}: 
{
  data_dir = ''''${HOME}/.local/mindwm/vector''; 
  sources.stdin = {
    type = "stdin";
    decoding.codec = "json";
  };
  sources.tmux_udp = {
    type = "socket";
    mode = "udp";
    decoding.codec = "bytes";
    address = "0.0.0.0:30007";
  };
  sources.feedback = {
    type = "nats";
    connection_name = "hostname-client-vector";
    subject = "${nats.subject}";
    url = "nats://${nats.host}:${toString nats.port}";
    auth.strategy = "user_password";
    auth.user_password = {
      user = "root";
      password = "r00tpass";
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
    address = "127.0.0.1:30007";
    version = "2";
    acknowledgements.enabled = false;
  };

  sinks.debug = {
    type = "console";
    inputs = [ "feedback" ];
    encoding.codec = "text";
  };
}
