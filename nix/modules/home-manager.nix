self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkPackageOption
    mkOption
    mkIf
    ;

  cfg = config.programs.nix-remote;
  tomlFormat = pkgs.formats.toml { };
in
{
  options.programs.nix-remote = {
    enable = mkEnableOption "nix-remote distributed builder orchestrator";

    package = mkPackageOption self.packages.${pkgs.stdenv.hostPlatform.system} "nix-remote" {
      pkgsText = "inputs.nix-remote-builders.packages.\${pkgs.stdenv.hostPlatform.system}";
    };

    settings = mkOption {
      inherit (tomlFormat) type;
      default = { };
      description = ''
        Configuration written to `~/.config/nix-remote/config.toml`.
      '';
      example = lib.literalExpression ''
        {
          repo = "my-org/my-infra";
        }
      '';
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.configFile."nix-remote/config.toml" = mkIf (cfg.settings != { }) {
      source = tomlFormat.generate "nix-remote-config.toml" cfg.settings;
    };
  };
}
