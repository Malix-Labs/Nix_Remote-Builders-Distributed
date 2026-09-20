{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    ;

  cfg = config.programs.nix-remote;
  tomlFormat = pkgs.formats.toml { };
in
{
  options.programs.nix-remote = {
    enable = mkEnableOption "nix-remote distributed builder orchestrator";

    package = mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../package.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage ../package.nix { }";
      description = "The nix-remote package to use.";
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
          environment = "Nix Builders"; # Optional: any custom environment name
          tailscale_tags = "tag:nix-builder"; # Optional: custom Tailscale ACL tags
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
