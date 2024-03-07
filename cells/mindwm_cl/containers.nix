{
  inputs,
  cell
}: let
  inherit (inputs) nixpkgs std self cells;
  l = nixpkgs.lib // builtins;

in {
  vector_back = std.lib.ops.mkStandardOCI rec {
    operable = cell.apps.vector_back;
    name = "vector-back";
    tag = "latest";
    inherit (operable) meta;
#    meta.mainProgram = "${operable.package}/out/vector";
  };
  vector_client = std.lib.ops.mkStandardOCI rec {
    operable = cell.apps.vector_client;
    name = "vector-client";
    tag = "latest";
    inherit (operable) meta;
#    meta.mainProgram = "${operable.package}/out/vector";
  };
  nats_back = std.lib.ops.mkStandardOCI rec {
    operable = cell.apps.nats_back;
    name = "nats-back";
    tag = "latest";
    inherit (operable) meta;
  };
}
