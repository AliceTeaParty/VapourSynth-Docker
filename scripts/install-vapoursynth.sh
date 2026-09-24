#!/usr/bin/env bash
set -euo pipefail

variant="${1:?usage: install-vapoursynth.sh generic|cu121|cu129}"
readonly api4_wheels_index="https://aliceteaparty.github.io/vapoursynth-api4-wheels/simple/"
build_constraint="$(mktemp)"
trap 'rm -f "$build_constraint"' EXIT
printf 'hatchling<1.32\n' > "$build_constraint"
export PIP_BUILD_CONSTRAINT="$build_constraint"

case "$variant" in
    generic)
        bm3d_package=vapoursynth-bm3dcpu
        dfttest2_package=vapoursynth-dfttest2-cpu
        vsmlrt_package=vs-mlrt-generic
        ;;
    cu121|cu129)
        bm3d_package="vapoursynth-bm3dcuda-${variant}"
        dfttest2_package="vapoursynth-dfttest2-${variant}"
        vsmlrt_package="vs-mlrt-${variant}"
        ;;
    *)
        echo "Unsupported VapourSynth variant: $variant" >&2
        exit 2
        ;;
esac

python3 -m pip install --upgrade pip setuptools wheel
python3 -m pip install --upgrade vapoursynth

python3 -m pip install --upgrade \
    --extra-index-url "$api4_wheels_index" \
    "$bm3d_package" \
    "$dfttest2_package" \
    "$vsmlrt_package" \
    vs-nlq \
    vapoursynth-nnedi3cl \
    vapoursynth-smoothuv \
    vapoursynth-dfttest \
    vapoursynth-knlm \
    vapoursynth-retinex \
    vapoursynth-tcomb \
    vapoursynth-tcanny \
    vapoursynth-misc \
    vapoursynth-fft3dfilter \
    vs-cfl

python3 -m pip install --upgrade \
    vapoursynth-vszip \
    vapoursynth-vszipcl \
    vapoursynth-zsmooth \
    vapoursynth-bestsource \
    vapoursynth-lsmas \
    vapoursynth-mvutensils \
    vapoursynth-nnedi3vk \
    vapoursynth-eedi3vk2

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
    vapoursynth-edgemasks

python3 -m pip install \
    "vapoursynth-tivtc @ git+https://github.com/RyougiKukoc/vapoursynth-tivtc-api4.git" \
    "vapoursynth-bifrost @ git+https://github.com/RyougiKukoc/vapoursynth-bifrost-vcs.git"

python3 -m pip install --force-reinstall \
    git+https://github.com/RyougiKukoc/rkstool.git \
    git+https://github.com/RyougiKukoc/rksfunc.git \
    "vs-collection-rk @ git+https://github.com/RyougiKukoc/VapourSynth-Scripts-Collection.git"
python3 -m pip install --upgrade getnative awsmfunc vsjetpack

python3 -m pip check
