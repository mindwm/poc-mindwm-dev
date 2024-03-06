lib: {
  nats
, vector
}: 
{
  data_dir = ''''${HOME}/.local/mindwm/vector''; 
  # Pipeline to convert a client bytestreams to words
  # and publigh the words to NATS topic
  sources.client_vector_words = {
    type = "vector";
    version = "2";
    address = ''''${MINDWM_BACK_VECTOR_ADDR}'';
    acknowledgements.enabled = false;
  };
# placeholder for some useful transformers
  transforms.final_state = {
    inputs = [ "client_vector_words" ];
    type = "remap";
    source = ''
    '';
  };
  sinks.mindwm_nats = {
    inputs = [ "final_state" ];
    type = "nats";
    subject = "io-document.words";
    url = ''nats://''${MINDWM_BACK_NATS_HOST}:''${MINDWM_BACK_NATS_PORT}'';
    encoding.codec = "json";
    auth.strategy = "user_password";
    auth.user_password = {
      user = ''''${MINDWM_BACK_NATS_USER}'';
      password = ''''${MINDWM_BACK_NATS_PASS}'';
    };
  };
}
