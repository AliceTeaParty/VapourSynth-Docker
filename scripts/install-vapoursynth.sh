#!/usr/bin/env bash
set -euo pipefail

variant="${1:?usage: install-vapoursynth.sh generic|cu121|cu129}"
readonly api4_wheels_index="https://aliceteaparty.github.io/vapoursynth-api4-wheels/simple/"
readonly requirements_dir="${VAPOURSYNTH_DOCKER_ROOT:?}/requirements"

case "$variant" in
    generic|cu121|cu129)
        ;;
    *)
        echo "Unsupported VapourSynth variant: $variant" >&2
        exit 2
        ;;
esac

python3 -m pip install --upgrade pip setuptools wheel
python3 -m pip install --upgrade "vapoursynth>=81"

python3 -m pip install --upgrade \
    --extra-index-url "$api4_wheels_index" \
    --only-binary=:all: \
    --requirement "${requirements_dir}/requirements-api4-common.txt" \
    --requirement "${requirements_dir}/requirements-api4-${variant}.txt"

python3 -m pip install --upgrade \
    vapoursynth-vszip \
    vapoursynth-vszipcl \
    vapoursynth-zsmooth \
    vapoursynth-bestsource \
    vapoursynth-lsmas \
    vapoursynth-mvutensils \
    vapoursynth-nnedi3vk \
    vapoursynth-eedi3vk2 \
    "vapoursynth-bm3dvk2>=2.0"

# vszipcu is the CUDA payload of vszip and needs an NVIDIA GPU plus NVRTC at
# runtime, so the generic variant deliberately leaves it out.
if [[ "$variant" != generic ]]; then
    python3 -m pip install --upgrade vapoursynth-vszipcu
fi

python3 -m pip install --upgrade \
    --extra-index-url https://jaded-encoding-thaumaturgy.github.io/vs-wheels/simple \
    vapoursynth-fmtconv \
    vapoursynth-ffms2

python3 -m pip install --upgrade \
    vapoursynth-descale \
    vs-placebo \
    vapoursynth-cambi \
    vapoursynth-fftspectrum_rs \
    vapoursynth-hysteresis \
    vapoursynth-manipmv \
    vapoursynth-sneedif \
    vapoursynth-resize2 \
    vsnoise \
    vapoursynth-subtext \
    vapoursynth-akarin \
    vsfpng \
    vapoursynth-deblock \
    vapoursynth-dctfilter \
    vapoursynth-mvtools \
    vapoursynth-vivtc \
    vapoursynth-znedi3 \
    vapoursynth-adaptivegrain \
    vapoursynth-edgefixer \
    vapoursynth-fillborders \
    vapoursynth-awarp \
    vapoursynth-sangnom \
    vapoursynth-bm3d \
    vapoursynth-eedi3 \
    vapoursynth-edgemasks \
    vapoursynth-tivtc \
    vapoursynth-bifrost

python3 -m pip install --upgrade getnative awsmfunc vsjetpack

# Keep the upstream-owned module versions unpinned. The Collection entry pins
# its own component wheels; this index supplies the entire script wheel set.
python3 -m pip install --upgrade \
    --index-url "$api4_wheels_index" \
    --only-binary=:all: \
    rkstool rksfunc vs-collection-rk

python3 -m pip check
