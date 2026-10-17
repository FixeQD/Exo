{
  nixLib,
  exoSource,
  inputs,
}: {
  config,
  pkgs,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;

  exoConfig = inputs.self.packages.${system}.exo-config;

  exoLib = import ./lib {lib = nixLib;};
in {
  imports = import ./options {
    context = {
      lib = nixLib;
      inherit config pkgs inputs exoSource exoConfig exoLib;
    };
  };
}
