let
  project = import ../default.nix { };
  inherit (project) compiler pkgs hsPkgs cardano-node;
in
pkgs.mkShell {
  name = "hydra-demo-shell";
  buildInputs = [
    cardano-node.cardano-node
    cardano-node.cardano-cli
    hsPkgs.hydra-node.components.exes.hydra-node
    hsPkgs.hydra-node.components.exes.hydra-tools
  ];
}
