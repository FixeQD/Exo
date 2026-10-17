{context}: let
  inherit (context) lib;
in [
  (import ./general.nix context)
  (import ./kitty.nix context)
  (import ./matugen.nix context)
  (import ./compositor.nix context)
]
