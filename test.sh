#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Root test wrapper script for Lyra
# Ensures tests are always executed inside the Nix environment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
nix-shell "${SCRIPT_DIR}/core/shell.nix" --run "python -m unittest discover -s '${SCRIPT_DIR}/core/tests'"
