{
  inputs,
  cell
}: let
  inherit (inputs) nixpkgs std self cells;
  l = nixpkgs.lib // builtins;

  name = "vector";
  operable = inputs.cells.vector.apps.vector;
in {
  vector = std.lib.ops.mkStandardOCI {
    inherit name operable;
    inherit (operable) meta;
  };
}
