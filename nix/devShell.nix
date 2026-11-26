{
  lib,
  stdenv,
  mkShell,
  alejandra,
  libabigail,
  nodejs,
  pinact,
  prettier,
  shellcheck,
  typos,
  zig,
}:
mkShell {
  packages =
    [
      # Build and test
      zig

      # Runs the wasm smoke test
      nodejs

      # Linters, the same ones libghostty-vt uses
      alejandra
      pinact
      prettier
      shellcheck
      typos
    ]
    # The ABI check, test/abi/check.sh. libabigail only reads ELF.
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      libabigail
    ];
}
