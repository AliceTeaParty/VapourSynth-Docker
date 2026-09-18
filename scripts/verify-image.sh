#!/usr/bin/env bash
set -euo pipefail

variant="${1:?usage: verify-image.sh cpu|cu121|cu129}"

for command in ts2_link x265 mkvmerge mkvinfo mkvextract tsMuxeR ffmpeg ffprobe; do
    command -v "$command" >/dev/null
done

python3 - "$variant" <<'PY'
import importlib.metadata as metadata
import sys
import vapoursynth as vs

variant = sys.argv[1]
required = ("VapourSynth", "vapoursynth-bm3dcuda", "vapoursynth-dfttest2", "vs-mlrt")
missing = []
for name in required:
    try:
        metadata.distribution(name)
    except metadata.PackageNotFoundError:
        missing.append(name)
if missing:
    raise SystemExit(f"missing required distributions: {', '.join(missing)}")
if vs.__api_version__.api_major < 4:
    raise SystemExit(f"expected VapourSynth API4, got {vs.__api_version__}")
core = vs.core
if not hasattr(core, "fmtc"):
    raise SystemExit("fmtconv did not register its fmtc namespace")
clip = core.std.BlankClip(width=16, height=16, length=1, format=vs.GRAY8)
if clip.get_frame(0).width != 16:
    raise SystemExit("VapourSynth core frame request failed")
print(f"VapourSynth API {vs.__api_version__.api_major} image verification passed for {variant}")
PY
