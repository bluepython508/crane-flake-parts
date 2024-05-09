{
  description = "Description for the project";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    crane-flake-parts = {
      url = "github:bluepython508/crane-flake-parts";
      inputs.rust-overlay.follows = "rust-overlay";
    };
  };

  outputs = inputs@{ flake-parts, crane-flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        crane-flake-parts.flakeModules.default
      ];
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      crane.source = ./.;
    };
}
