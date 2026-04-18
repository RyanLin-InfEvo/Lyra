{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  # 編譯工具
  nativeBuildInputs = with pkgs; [
    cmake
    gnumake
    pkg-config
  ];

  # 程式碼依賴的函式庫
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
