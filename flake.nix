{
  description = "Declarative DeepSeek Harness on Nix (dsh — DeepSeek's plugin-based AI agent harness)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      packagesFor =
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        rec {
          deepseek-harness = pkgs.callPackage ./pkgs/deepseek-harness { };
          default = deepseek-harness;
        };
    in
    {
      packages = forAllSystems packagesFor;

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.deepseek-harness}/bin/dsh";
        };
      });

      homeModules.deepseek-harness =
        { lib, pkgs, ... }:
        {
          imports = [ ./modules/home-manager/deepseek-harness.nix ];
          programs.deepseek-harness.package = lib.mkDefault (
            self.packages.${pkgs.stdenv.hostPlatform.system}.deepseek-harness
          );
        };
      homeModules.default = self.homeModules.deepseek-harness;

      overlays.default = final: _prev: {
        inherit (self.packages.${final.stdenv.hostPlatform.system}) deepseek-harness;
      };
    };
}
