#!/usr/bin/env bash
set -euo pipefail

variant="${1:?usage: verify-image.sh generic|cu121|cu129}"

for command in ts2_link x265 mkvmerge mkvinfo mkvextract tsMuxeR ffmpeg ffprobe qaac64; do
    command -v "$command" >/dev/null
done
qaac_prefix="$(mktemp -d)"
trap 'WINEPREFIX="$qaac_prefix" wineserver -k >/dev/null 2>&1 || true; rm -rf "$qaac_prefix"' EXIT
mkdir -p -m 700 "$qaac_prefix/runtime"
WINEPREFIX="$qaac_prefix" WINEARCH=win64 XDG_RUNTIME_DIR="$qaac_prefix/runtime" qaac64 --check

python3 "${VAPOURSYNTH_DOCKER_ROOT:?}/verify-packages.py" "$variant"
python3 -m pip check
