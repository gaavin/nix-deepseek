{
  config,
  lib,
  ...
}:

let
  inherit (lib)
    literalExpression
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.programs.deepseek-harness;
in
{
  options.programs.deepseek-harness = {
    enable = mkEnableOption "DeepSeek Harness (dsh agent harness via nix-deepseek)";

    package = mkOption {
      type = types.nullOr types.package;
      default = null;
      defaultText = literalExpression "nix-deepseek.packages.\${pkgs.stdenv.hostPlatform.system}.deepseek-harness";
      example = literalExpression "nix-deepseek.packages.\${pkgs.stdenv.hostPlatform.system}.deepseek-harness";
      description = ''
        deepseek-harness package to install. When you import
        `nix-deepseek.homeModules.deepseek-harness` from the flake, this
        defaults to that flake's `deepseek-harness` — you usually do not need
        to set it.
      '';
    };
  };

  config = mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;

    assertions = [
      {
        assertion = cfg.package != null;
        message = ''
          programs.deepseek-harness.package is unset. Import
          nix-deepseek.homeModules.deepseek-harness from the flake
          (which sets a default), or set package explicitly to
          nix-deepseek.packages.''${pkgs.stdenv.hostPlatform.system}.deepseek-harness.
        '';
      }
    ];
  };
}
