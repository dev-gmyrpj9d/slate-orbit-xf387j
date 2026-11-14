#!/usr/bin/env bash
# Full offline gate: format check, tests, build, round-trip and strict type analysis.
# Needs lune, stylua and luau-lsp (see mise.toml) plus Roblox type definitions; set
# ROBLOX_DEFS to a local copy of luau-lsp's globalTypes.d.luau or it is downloaded.
set -euo pipefail
cd "$(dirname "$0")/.."
DEFS="${ROBLOX_DEFS:-build/globalTypes.d.luau}"
if [ ! -f "$DEFS" ]; then
	curl -sSfL -o "$DEFS" https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
fi
stylua --check src tests tools
lune run tests/run.luau
lune run tools/build.luau
lune run tools/roundtrip.luau place/WildFeastIslands.original.rbxl build/WildFeastIslands.rbxl
lune run tools/sourcemap.luau
luau-lsp analyze --definitions="$DEFS" --sourcemap=sourcemap.json src
