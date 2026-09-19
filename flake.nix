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
              nix-fast-build
            ];
            text = ''
              exec nu "${./src/nix-remote.nu}" "$@"
            '';
          };
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

          # Waiting for https://github.com/cachix/git-hooks.nix/pull/743
          formatter =
            let
              cfg = config.pre-commit.settings;
            in
            pkgs.writeShellScriptBin "pre-commit-fmt" ''
              set -euo pipefail
              export PATH="${
                pkgs.lib.makeBinPath (
                  [
                    cfg.gitPackage
                    cfg.package
                  ]
                  ++ cfg.enabledPackages
                )
              }:$PATH"

              exitcode=0
              if [ "$#" -gt 0 ]; then
                ${pkgs.lib.getExe cfg.package} run -c ${cfg.configFile} --files "$@" || exitcode=$?
              else
                if [ -n "''${PRJ_ROOT:-}" ]; then
                  cd "$PRJ_ROOT"
                fi
                ${pkgs.lib.getExe cfg.package} run -c ${cfg.configFile} --all-files || exitcode=$?
              fi

              # pre-commit returns 1 when files were modified by hooks.
              # For a formatter (`nix fmt`), modifying files is the intended outcome.
              # If exit code was 1, re-run to distinguish between successful formatting changes (clean on 2nd pass)
              # and actual errors/syntax failures (fails again on 2nd pass).
              if [ "$exitcode" -eq 1 ]; then
                if [ "$#" -gt 0 ]; then
                  ${pkgs.lib.getExe cfg.package} run -c ${cfg.configFile} --files "$@"
                else
                  ${pkgs.lib.getExe cfg.package} run -c ${cfg.configFile} --all-files
                fi
              else
                exit "$exitcode"
              fi
            '';

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
              nix-fast-build
            ];
          };
        };
    };
}
