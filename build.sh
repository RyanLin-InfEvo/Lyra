#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Root build wrapper script for Lyra
# Ensures compilation is always executed inside the Nix environment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
nix-shell "${SCRIPT_DIR}/core/shell.nix" --run "cd '${SCRIPT_DIR}/core' && ./build.sh"
