#!/usr/bin/env bash
set -euo pipefail

variant="${1:?usage: install-vapoursynth.sh cpu|cu121|cu129}"
build_constraint="$(mktemp)"
trap 'rm -f "$build_constraint"' EXIT
printf 'hatchling<1.32\n' > "$build_constraint"
export PIP_BUILD_CONSTRAINT="$build_constraint"

case "$variant" in
    cpu)
        bm3dcuda_ref=cpu
        dfttest2_ref=cpu
        vsmlrt_ref=generic
        ;;
    cu121|cu129)
        bm3dcuda_ref="$variant"
        dfttest2_ref="$variant"
        vsmlrt_ref="$variant"
        ;;
    *)
        echo "Unsupported VapourSynth variant: $variant" >&2
        exit 2
        ;;
esac

python3 -m pip install --upgrade pip setuptools wheel
python3 -m pip install --upgrade vapoursynth

python3 -m pip install \
    "vapoursynth-bm3dcuda @ git+https://github.com/RyougiKukoc/VapourSynth-BM3DCUDA-api4.git@${bm3dcuda_ref}" \
    "vapoursynth-dfttest2 @ git+https://github.com/RyougiKukoc/vs-dfttest2-api4.git@${dfttest2_ref}" \
    "vs-mlrt @ git+https://github.com/RyougiKukoc/vs-mlrt-api4.git@${vsmlrt_ref}"

python3 -m pip install --upgrade \
    vapoursynth-vszip \
    vapoursynth-vszipcl \
    vapoursynth-vszipcu \
    vapoursynth-zsmooth \
    vapoursynth-bestsource \
    vapoursynth-lsmas \
    vapoursynth-mvutensils \
    vapoursynth-nnedi3vk \
    vapoursynth-eedi3vk2

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
    "vs-nlq @ git+https://github.com/RyougiKukoc/vs-nlq.git" \
    "vapoursynth-nnedi3cl @ git+https://github.com/RyougiKukoc/VapourSynth-NNEDI3CL-api4.git" \
    "vapoursynth-smoothuv @ git+https://github.com/RyougiKukoc/vapoursynth-smoothuv-api4.git" \
    "vapoursynth-dfttest @ git+https://github.com/RyougiKukoc/VapourSynth-DFTTest-api4.git" \
    "vapoursynth-knlm @ git+https://github.com/RyougiKukoc/VapourSynth-KNLMeansCL-api4.git" \
    "vapoursynth-retinex @ git+https://github.com/RyougiKukoc/VapourSynth-Retinex-api4.git" \
    "vapoursynth-tivtc @ git+https://github.com/RyougiKukoc/vapoursynth-tivtc-api4.git" \
    "vapoursynth-tcomb @ git+https://github.com/RyougiKukoc/vapoursynth-tcomb-api4.git" \
    "vapoursynth-tcanny @ git+https://github.com/RyougiKukoc/VapourSynth-TCanny-vcs.git" \
    "vapoursynth-bifrost @ git+https://github.com/RyougiKukoc/vapoursynth-bifrost-vcs.git" \
    "vapoursynth-misc @ git+https://github.com/RyougiKukoc/vs-miscfilters-obsolete-vcs.git" \
    "vapoursynth-fft3dfilter @ git+https://github.com/RyougiKukoc/VapourSynth-FFT3DFilter-vcs.git" \
    "vs-cfl @ git+https://github.com/RyougiKukoc/vs-cfl-vcs.git"

python3 -m pip install --force-reinstall \
    git+https://github.com/RyougiKukoc/rkstool.git \
    git+https://github.com/RyougiKukoc/rksfunc.git \
    "vs-collection-rk @ git+https://github.com/RyougiKukoc/VapourSynth-Scripts-Collection.git"
python3 -m pip install --upgrade getnative awsmfunc vsjetpack

python3 -m pip check
