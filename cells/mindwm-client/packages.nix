{ inputs
, cell
}:
let
  inherit (inputs) std self cells;
  inherit (inputs) nixpkgs;

  l = nixpkgs.lib // builtins;
in
{
  vector = nixpkgs.vector;
}
