#!/usr/bin/env bash

# If ~/vcpkg exists, use it
if [ -f "$HOME/vcpkg/scripts/buildsystems/vcpkg.cmake" ]; then
    VCPKG_TOOLCHAIN="-DCMAKE_TOOLCHAIN_FILE=$HOME/vcpkg/scripts/buildsystems/vcpkg.cmake"
    echo "Using vcpkg toolchain..."
else
    VCPKG_TOOLCHAIN=""
    echo "vcpkg not found, assuming dependencies are provided by system (Nix/apt/brew)..."
fi

cmake -B build -S . $VCPKG_TOOLCHAIN
cmake --build build

if [ -f compile_commands.json ] || [ -f build/compile_commands.json ]; then
    ln -sf build/compile_commands.json compile_commands.json
fi