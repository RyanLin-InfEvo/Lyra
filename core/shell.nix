{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell rec {
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
    export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath buildInputs}:$LD_LIBRARY_PATH"
    echo "❄️ Lyra Core development environment (NixOS) is ready!"
    echo "You can directly execute: ./build.sh"
  '';
}

