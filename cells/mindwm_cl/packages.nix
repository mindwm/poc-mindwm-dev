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
  nats = nixpkgs.nats-server;
  tmux = nixpkgs.tmux;
  tmuxinator = nixpkgs.tmuxinator;

  mindwm_current_subject = nixpkgs.stdenv.mkDerivation rec {
      pname = "current-subject";
      version = "0.0.1.0";
      buildInputs = [ nixpkgs.bash ];
      src = ./scripts; #(builtins.readFile ./scripts/get_current_subject.sh);
      installPhase = ''
        mkdir -p $out/bin
        cp get_current_subject.sh $out/bin/get_current_subject.sh
      '';
  };
}
