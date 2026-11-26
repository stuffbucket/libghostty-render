{
  description = "libghostty-render";

  inputs = {
    # flake.lock pins these to the same revisions as the flake.lock of
    # Ghostty vt-1.0.1, the libghostty-vt release this library builds on, so
    # the tools match the ones libghostty-vt is checked with. Update them
    # together with the ghostty dependency in build.zig.zon.
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };

    systems = {
      url = "github:nix-systems/default";
      flake = false;
    };

    zig = {
      url = "github:mitchellh/zig-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";
        systems.follows = "systems";
      };
    };
  };

  outputs = {
    nixpkgs,
    zig,
    ...
  }: let
    inherit (nixpkgs) lib legacyPackages;

    # The systems the Zig binaries support.
    platforms = lib.attrNames zig.packages;

    forAllPlatforms = f: lib.genAttrs platforms (s: f legacyPackages.${s});
  in {
    devShells = forAllPlatforms (pkgs: {
      default = pkgs.callPackage ./nix/devShell.nix {
        # The minimum Zig version in build.zig.zon.
        zig = zig.packages.${pkgs.stdenv.hostPlatform.system}."0.17.0";
      };
    });

    formatter = forAllPlatforms (pkgs: pkgs.alejandra);
  };
}
