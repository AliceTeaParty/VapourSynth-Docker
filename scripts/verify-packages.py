#!/usr/bin/env python3
"""Check installed wheel identity and the selected image's runtime layout."""
from __future__ import annotations

import importlib.metadata as metadata
import importlib.util
import json
from pathlib import Path
import sys


VARIANTS = ("generic", "cu121", "cu129")
ROOT = Path(__file__).resolve().parent


def requirements(group: str) -> dict[str, str]:
    result = {}
    for line in (ROOT / "requirements" / f"requirements-api4-{group}.txt").read_text().splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        name, separator, version = line.partition("==")
        if not separator or not name or not version:
            raise RuntimeError(f"Expected an exact API4 wheel version: {line}")
        result[name] = version
    return result


def verify(variant: str) -> None:
    if variant not in VARIANTS:
        raise ValueError(f"Unsupported image variant: {variant}")
    expected = {**requirements("common"), **requirements(variant)}
    for name, version in expected.items():
        actual = metadata.version(name)
        if actual != version:
            raise RuntimeError(f"{name}: expected {version}, installed {actual}")
    for other in set(VARIANTS) - {variant}:
        for name in requirements(other):
            try:
                metadata.distribution(name)
            except metadata.PackageNotFoundError:
                continue
            raise RuntimeError(f"Conflicting image variant is installed: {name}")

    # Scripts and upstream plugins must use their published index packages.
    for name in (
        "rksfunc", "rkstool", "vs-collection-rk",
        "vapoursynth-tivtc", "vapoursynth-bifrost", "vapoursynth-bm3dvk2",
    ):
        distribution = metadata.distribution(name)
        if direct_url := distribution.read_text("direct_url.json"):
            if "vcs_info" in json.loads(direct_url):
                raise RuntimeError(f"{name} still comes from a VCS install")
    for name in ("rksfunc", "rkstool"):
        if importlib.util.find_spec(name) is None:
            raise RuntimeError(f"Missing script module: {name}")
    import vs_collection_rk
    for component in vs_collection_rk.load_registry():
        name = component["distribution"]
        if metadata.version(name) != component["wheel_version"]:
            raise RuntimeError(f"Collection component version disagrees with the entry: {name}")
        if importlib.util.find_spec(component["import_name"]) is None:
            raise RuntimeError(f"Missing Collection import: {component['import_name']}")

    for name in ("vapoursynth-vszip", "vapoursynth-vszipcl", "vapoursynth-vszipcu"):
        try:
            metadata.distribution(name)
            installed = True
        except metadata.PackageNotFoundError:
            installed = False
        wanted = variant != "generic" if name == "vapoursynth-vszipcu" else True
        if installed != wanted:
            raise RuntimeError(f"{name}: installed={installed}, expected={wanted}")

    import vapoursynth as vs
    import vsmlrt
    if vs.__api_version__.api_major < 4:
        raise RuntimeError(f"Expected VapourSynth API4, got {vs.__api_version__}")
    if vs.__version__.release_major < 81:
        raise RuntimeError(f"Expected VapourSynth R81+, got {vs.__version__}")
    plugin_root = Path(vsmlrt.plugins_path)
    native_files = ["vsncnn.so", "vsov.so", "manifest.vs"]
    if variant != "generic":
        native_files += ["vstrt.so", "vsmlrt-cuda/trtexec", "vsmlrt-cuda/trtexec-build.json"]
    if variant == "cu129":
        native_files += ["vstrt_rtx.so", "vsmlrt-cuda/tensorrt_rtx"]
    for name in native_files:
        if not (plugin_root / name).is_file():
            raise RuntimeError(f"Missing vs-mlrt payload: {name}")
    if variant == "generic":
        core = vs.core
        for namespace in ("fmtc", "krigvk", "dfttestvk", "bm3dvk2", "tivtc", "bifrost"):
            if not hasattr(core, namespace):
                raise RuntimeError(f"Plugin did not register its {namespace} namespace")
        clip = core.std.BlankClip(width=16, height=16, length=1, format=vs.GRAY8)
        if clip.get_frame(0).width != 16:
            raise RuntimeError("VapourSynth frame request failed")
        clip = core.std.BlankClip(width=16, height=16, length=1, format=vs.YUV444PS, color=[0.5] * 3)
        if core.bm3dcpu.BM3D(clip, sigma=[1.0] * 3, radius=0).get_frame(0).width != 16:
            raise RuntimeError("BM3D CPU frame request failed")
        clip = core.std.BlankClip(width=64, height=48, length=10, format=vs.YUV420P8)
        for filtered in (core.tivtc.TFM(clip, order=1), core.bifrost.Bifrost(clip)):
            if filtered.get_frame(5).width != 64:
                raise RuntimeError("TIVTC/Bifrost frame request failed")
    print(f"Verified {len(expected)} API4 wheel pins, script wheels and {variant} payload layout")


if __name__ == "__main__":
    verify(sys.argv[1])
