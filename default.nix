{ pkgs, ... }:
let
  package = pkgs.callPackage ./nix/package.nix { };
  homeManagerModule = import ./nix/modules/home-manager.nix;
in
package
// {
  homeManagerModules = {
    nix-remote = homeManagerModule;
    default = homeManagerModule;
  };
}
