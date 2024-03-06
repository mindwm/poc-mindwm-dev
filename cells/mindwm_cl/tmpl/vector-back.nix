lib: {
  nats
, vector
}: 
{
  data_dir = ''''${HOME}/.local/mindwm/vector''; 
  # Pipeline to convert a client bytestreams to words
  # and publigh the words to NATS topic
  sources.client_vectors = {
    type = "vector";
    version = "2";
    address = "${vector.bind_address}:${toString vector.port}";
    acknowledgements.enabled = false;
  };
  transforms.words = {
    inputs = [ "client_vectors" ];
    type = "reduce";
    ends_when.type = "vrl";
    ends_when.source = ''
      .message == " " || .message == "\n" || .message == "\r" || .message == "\t"
    '';
    merge_strategies.message = "concat_raw";
  };
  sinks.nats_words = {
    inputs = [ "words" ];
    type = "nats";
    subject = "io-document.words";
    url = "nats://${nats.address}:${nats.port}";
    encoding.codec = "json";
    auth.strategy = "user_password";
    auth.user_password = {
      user = "root";
      password = "r00tpass";
    };
  };
}
