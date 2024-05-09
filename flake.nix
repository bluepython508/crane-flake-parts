{
  description = "A flake-parts module for `crane`";

  inputs = {
    crane.url = "github:ipetkov/crane";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = inputs: {
    flakeModules.default = import ./module.nix inputs;
    templates.default = {
      path = ./tmpl;
      description = "A template for use of this flake-parts module";
    };
  };
}
