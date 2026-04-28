{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    cmake
    gnumake
    pkg-config
  ];

  buildInputs = with pkgs; [
    nlohmann_json
    fmt
    sqlitecpp
    sqlite
    stduuid
    tl-expected
  ];

  shellHook = ''
    echo "❄️ Lyra Core development environment (NixOS) is ready!"
    echo "You can directly execute: ./build.sh"
  '';
}
