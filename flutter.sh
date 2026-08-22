#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Root Flutter wrapper script for Lyra
# Ensures Flutter commands are always executed inside the Nix environment with UI context

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UI_DIR="${SCRIPT_DIR}/ui"

if [ ! -d "${UI_DIR}" ]; then
  mkdir -p "${UI_DIR}"
fi

CMD="cd '${UI_DIR}' && flutter"
if [ $# -gt 0 ]; then
  CMD="${CMD} $(printf '%q ' "$@")"
fi

nix-shell "${UI_DIR}/shell.nix" --run "${CMD}"
