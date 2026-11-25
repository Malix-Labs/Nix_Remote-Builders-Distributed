{
  description = "Remote Builders Distributed";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.zst";

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
        homeManagerModules =
          let
            homeManagerModule = import ./nix/modules/home-manager.nix;
          in
          {
            nix-remote = homeManagerModule;
            default = homeManagerModule;
          };
      };

      perSystem =
        {
          config,
          pkgs,
          ...
        }:
        let
          nix-remote = pkgs.callPackage ./nix/package.nix { };
        in
        {
          pre-commit.settings.hooks = {
            nixfmt.enable = true;
            deadnix.enable = true;
            statix.enable = true;
            nufmt = {
              enable = true;
              types = [ "file" ];
              files = "\\.nu$";
            };
            nu-check = {
              enable = true;
              name = "nu-check";
              description = "Validate and parse Nushell scripts";
              package = pkgs.nushell;
              entry = "${pkgs.lib.getExe pkgs.nushell} -c 'def main [...files: string] { mut err = false; for f in $files { if not (nu-check --debug ($f | path expand)) { $err = true } }; if $err { exit 1 } }' --";
              files = "\\.nu$";
            };
            nu-lint = {
              enable = true;
              name = "nu-lint";
              description = "A linter for Nushell scripts";
              package = pkgs.nu-lint;
              entry = pkgs.lib.getExe pkgs.nu-lint;
              files = "\\.nu$";
            };
            actionlint.enable = true;
          };

          packages = {
            inherit nix-remote;
            default = nix-remote;
          };

          devShells.default = pkgs.mkShell {
            inputsFrom = [
              config.pre-commit.devShell
            ];
            packages = with pkgs; [
              nushell
              nix-eval-jobs
              nix-fast-build
            ];
          };
        };
    };
}
