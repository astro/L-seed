{ pkgs ? import <nixpkgs> {} }:

with pkgs;

mkShell {
  nativeBuildInputs = [
    pkgconfig ghc cabal-install
  ];
  buildInputs = [
    cairo pango gtk2
  ];
}
