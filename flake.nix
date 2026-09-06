{
  description = "Remote Builders Distributed";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";

    systems.url = "github:nix-systems/default";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.git-hooks.flakeModule
      ];

      systems = import inputs.systems;

      flake = {
        homeManagerModules = {
          default = inputs.self.homeManagerModules.nix-remote;
          nix-remote = import ./nix/modules/home-manager.nix inputs.self;
        };
      };

      perSystem =
        {
          config,
          pkgs,
          ...
        }:
        let
          nix-remote = pkgs.writeShellApplication {
            name = "nix-remote";
            runtimeInputs = with pkgs; [
              nushell
              nix-eval-jobs
            ];
            text = ''
              exec nu "${./src/nix-remote}" "$@"
            '';
          };
        in
        {
          pre-commit.settings.hooks = {
            nixfmt.enable = true;
            deadnix.enable = true;
            statix.enable = true;
          };

          formatter = pkgs.nixfmt;

          packages = {
            default = nix-remote;
            inherit nix-remote;
          };

          devShells.default = pkgs.mkShell {
            inputsFrom = [
              config.pre-commit.devShell
            ];
            packages = with pkgs; [
              nushell
              nix-eval-jobs
            ];
          };
        };
    };
}
