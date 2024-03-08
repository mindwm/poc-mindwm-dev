{
  inputs,
  cell
}: let
  inherit (inputs) nixpkgs std self cells;
  l = nixpkgs.lib // builtins;

in {
  vector_back = std.lib.ops.mkStandardOCI rec {
    operable = cell.apps.vector_back;
    name = "mindwm/vector-back";
    tag = "latest";
    inherit (operable) meta;
#    meta.mainProgram = "${operable.package}/out/vector";
  };
  vector_client = std.lib.ops.mkStandardOCI rec {
    operable = cell.apps.vector_client;
    name = "mindwm/vector-client";
    tag = "latest";
    inherit (operable) meta;
#    meta.mainProgram = "${operable.package}/out/vector";
  };
  nats_back = std.lib.ops.mkStandardOCI rec {
    operable = cell.apps.nats_back;
    name = "mindwm/nats-back";
    tag = "latest";
    inherit (operable) meta;
  };
  mindwm_client = std.lib.ops.mkStandardOCI rec {
#operable = cell.apps.mindwm_client;
    operable = cell.apps.runTmuxSession;
    name = "mindwm/mindwm-client";
    tag = "latest";
    inherit (operable) meta;
  };
}
