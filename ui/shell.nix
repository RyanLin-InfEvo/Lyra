{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell rec {
  nativeBuildInputs = with pkgs; [
    cmake
    ninja
    pkg-config
    clang
  ];

  buildInputs = with pkgs; [
    # Flutter SDK and Web support
    flutter
    chromium

    # Linux Desktop Flutter dependencies
    gtk3
    glib
    pcre2
    libx11
    libxrandr
    libxcursor
    libxinerama
    libxi
    libepoxy

    # Lyra Core dependencies
    nlohmann_json
    fmt
    sqlitecpp
    sqlite
    stduuid
    tl-expected
    ffmpeg
  ];

  # Environment variables for Flutter tools
  CHROME_EXECUTABLE = "${pkgs.chromium}/bin/chromium";

  shellHook = ''
    export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath buildInputs}:$LD_LIBRARY_PATH"
    export CHROME_EXECUTABLE="${pkgs.chromium}/bin/chromium"
    echo "Lyra UI Flutter development environment (NixOS) is ready!"
  '';
}
