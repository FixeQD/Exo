{
  description = "Exo desktop shell as a Hjem module";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    ignis = {
      url = "github:ignis-sh/ignis";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    ignis,
    ...
  }: let
    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    packages = forAllSystems (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        exo-config = pkgs.runCommand "exo-config" {} ''
          mkdir -p "$out/share/exo"
          cp -r ${./ignis} "$out/share/exo/ignis"
          cp -r ${./matugen} "$out/share/exo/matugen"
          cp -r ${./nix} "$out/share/exo/nix"
        '';

        default = self.packages.${system}.exo-config;
      }
    );

    hjemModules.exo = import ./nix/module.nix {
      nixLib = nixpkgs.lib;
      exoSource = ./.;
      inputs = {
        inherit self nixpkgs ignis;
      };
    };

    hjemModules.default = self.hjemModules.exo;

    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);
  };
}
