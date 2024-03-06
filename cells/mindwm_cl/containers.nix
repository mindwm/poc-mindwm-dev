{
  inputs,
  cell
}: let
  inherit (inputs) nixpkgs std self cells;
  l = nixpkgs.lib // builtins;

in {
  vector_back = std.lib.ops.mkStandardOCI rec {
    operable = cell.apps.vector_back;
    name = "vector";
    tag = "latest";
    inherit (operable) meta;
#    meta.mainProgram = "${operable.package}/out/vector";
  };
  nats_back = std.lib.ops.mkStandardOCI rec {
    operable = cell.apps.nats_back;
    name = "nats";
    tag = "latest";
    inherit (operable) meta;
  };
}
