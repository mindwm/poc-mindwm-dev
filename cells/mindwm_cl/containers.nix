{
  inputs,
  cell
}: let
  inherit (inputs) nixpkgs std self cells;
  l = nixpkgs.lib // builtins;

in {
  vector = std.lib.ops.mkStandardOCI rec {
    operable = cell.apps.vector;
    name = "vector";
    tag = "latest";
    inherit (operable) meta;
#    meta.mainProgram = "${operable.package}/out/vector";
  };
  nats = std.lib.ops.mkStandardOCI rec {
    operable = cell.apps.nats;
    name = "nats-server";
    tag = "latest";
    inherit (operable) meta;
  };
}
