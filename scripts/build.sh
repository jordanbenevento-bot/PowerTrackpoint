#!/usr/bin/env bash
# Build de PowerTrackpoint: cross-compila con mingw-w64.
#   - bin/TrackPointQuickMenu.exe  -> cliente (lo lanza la activacion de protocolo
#       MSIX; NO lleva uiAccess porque la activacion lo rechaza con 0x300D).
#   - bin/tphandler_helper.exe     -> helper residente con uiAccess embebido (lo
#       lanza Task Scheduler; salta UIPI para clickear sobre ventanas de admin).
#
# Requisitos: paquete mingw-w64 (x86_64-w64-mingw32-gcc, ...-windres).
# Uso: bash scripts/build.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CC=x86_64-w64-mingw32-gcc
WINDRES=x86_64-w64-mingw32-windres
OUT="$ROOT/bin"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT"

echo "[build] cliente (sin uiAccess)..."
"$CC" -O2 -s -mwindows \
    "$ROOT/src/tphandler_client.c" \
    -o "$OUT/TrackPointQuickMenu.exe" -luser32

echo "[build] recurso uiAccess (para el helper)..."
"$WINDRES" -I "$ROOT/src" "$ROOT/src/resource.rc" -o "$TMP/resource.o"

echo "[build] helper (uiAccess embebido)..."
"$CC" -O2 -s -mwindows \
    "$ROOT/src/tphandler_helper.c" "$TMP/resource.o" \
    -o "$OUT/tphandler_helper.exe" -luser32

echo "[build] OK"
file "$OUT/TrackPointQuickMenu.exe" "$OUT/tphandler_helper.exe" 2>/dev/null || true
