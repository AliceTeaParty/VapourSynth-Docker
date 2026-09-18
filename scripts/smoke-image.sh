#!/usr/bin/env bash
set -euo pipefail

variant="${1:?usage: smoke-image.sh cpu|cu121|cu129}"
for command in ts2_link x265 mkvmerge mkvinfo mkvextract tsMuxeR ffmpeg ffprobe qaac64; do
    command -v "$command" >/dev/null
done
test -x "${VAPOURSYNTH_DOCKER_ROOT:?}/update-tools.sh"
qaac_prefix="$(mktemp -d)"
trap 'WINEPREFIX="$qaac_prefix" wineserver -k >/dev/null 2>&1 || true; rm -rf "$qaac_prefix"' EXIT
mkdir -p -m 700 "$qaac_prefix/runtime"
WINEPREFIX="$qaac_prefix" WINEARCH=win64 XDG_RUNTIME_DIR="$qaac_prefix/runtime" qaac64 --check
python3 - "$variant" <<'PY'
import sys
import vapoursynth as vs

assert vs.__api_version__.api_major >= 4, vs.__api_version__
if sys.argv[1] == "cpu":
    core = vs.core
    assert hasattr(core, "fmtc")
    clip = core.std.BlankClip(width=16, height=16, length=1, format=vs.GRAY8)
    assert clip.get_frame(0).width == 16
print(f"runtime smoke passed for {sys.argv[1]}")
PY
