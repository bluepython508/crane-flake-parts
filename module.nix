{
  crane,
  rust-overlay,
  ...
}: {
  lib,
  config,
  inputs,
  ...
}: let
  cfg = config.crane;
  filteredSource = lib.cleanSourceWith (let
    # craneLib.path isn't system- or pkgs- dependent, so arbitrary system is safe
    src = crane.lib.aarch64-linux.path config.crane.source;
  in {
    src = lib.cleanSource src;
    filter = path: type: (
      builtins.any (f:
        if builtins.isString f
        then lib.removePrefix "${src}/" path == f
        else f path type)
      cfg.includeSource);
  });
in {
  options.crane = {
    overlays = lib.mkOption {
      description = "Overlays applied to crane.pkgs";
      type = with lib.types; listOf (functionTo (functionTo attrs));
    };
    toolchain = lib.mkOption {
      description = "The rustup toolchain file";
      type = lib.types.pathInStore;
      default = "${filteredSource}/toolchain.toml";
      defaultText = lib.options.literalExpression "{source}/toolchain.toml";
    };
    source = lib.mkOption {
      description = "The source code";
      type = lib.types.path;
      example = lib.options.literalExpression "./.";
    };
    includeSource = lib.mkOption {
      description = ''
        Filters for the source code.
        `.rs` and `.toml` files, as well as `Cargo.lock` and `.cargo/config`, are included by default.
        All files matching any filter are included.
        Functions should be of the form `path: type: true`, where `type` is `"directory"` or `"file"`.
      '';
      type = with lib.types; listOf (oneOf [str (functionTo (functionTo bool))]);
    };
  };
  config = {
    crane.overlays = [rust-overlay.overlays.default];
    # craneLib.filterCargoSources isn't system- or pkgs- dependent, so arbitrary system is safe
    # Using a different system from previous to crash things if that's necessary
    crane.includeSource = [crane.lib.x86_64-linux.filterCargoSources];

    perSystem = {
      config,
      system,
      ...
    }: let
      cfg' = config.crane;
      craneLib = (crane.mkLib cfg'.pkgs).overrideToolchain cfg'.toolchain;
    in {
      options.crane = {
        pkgs = lib.mkOption {
          description = "The `nixpkgs` instance for crane to use. Expects a `rust-bin` package to be present";
          type = lib.types.pkgs;
          default = import inputs.nixpkgs {
            inherit system;
            overlays = cfg.overlays;
          };
          defaultText = lib.options.literalExpression ''              
            import inputs.nixpkgs {
              inherit system;
              overlays = [rust-overlay];
            }'';
        };
        packages = lib.mkOption {
          description = "Packages to build with crane.
           Each will populate `perSystem.packages.\${name}`, with the value being additional arguments to pass to crane.";
          type = with lib.types; attrsOf attrs;
          default = {default = {};};
        };
        toolchain = lib.mkOption {
          description = "The rust toolchain to use. Prefer the global `crane.toolchain` option.";
          type = lib.types.package;
          default = cfg'.pkgs.rust-bin.fromRustupToolchainFile cfg.toolchain;
          defaultText = lib.options.literalMD "Based on the global `crane.toolchain` option.";
        };
        craneDepsArgs = lib.mkOption {
          description = "Arguments to pass to `buildDepsOnly`.
          This is mostly useful if a dependency requires additional build inputs.";
          type = with lib.types; attrsOf anything;
          default.src = filteredSource;
        };
        craneArgs = lib.mkOption {
          description = "The materialized crane args";
          type = with lib.types; attrsOf anything;
          default = {
            src = filteredSource;
            cargoArtifacts = craneLib.buildDepsOnly cfg'.craneDepsArgs;
          };
        };
        shell = {
          enable = lib.mkEnableOption "devshell" // { default = true; };
          args = lib.mkOption {
            description = "Arguments to the devshell. Passed through to `mkShell`";
            type = lib.types.attrs;
            default = {};
          };
        };
      };
      config = {
        packages = builtins.mapAttrs (name: args: craneLib.buildPackage (cfg'.craneArgs // args)) cfg'.packages;
        checks =
          lib.concatMapAttrs (name: args: {
            "${name}-build" = config.packages.${name};
            "${name}-clippy" = craneLib.cargoClippy (cfg'.craneArgs // args);
          })
          cfg'.packages;
        devShells.default = lib.mkIf cfg'.shell.enable (craneLib.devShell ({inputsFrom = lib.attrValues config.packages;} // cfg'.shell.args));
      };
    };
  };
}
