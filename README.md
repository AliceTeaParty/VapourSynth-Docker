# VapourSynth Docker

Three Linux x86_64 images provide a Python 3.13 VapourSynth API4 environment
for encode work. They contain one system-level Python installation and do not
use Conda. `python` is an explicit symlink to that same `python3` interpreter.

| Image tag | Special plugin refs | GPU requirement |
| --- | --- | --- |
| `cpu` | BM3DCUDA `cpu`, DFTTest2 `cpu`, vs-mlrt `generic` | None |
| `cu121` | all three at `cu121` | NVIDIA driver supporting CUDA 12.1 |
| `cu129` | all three at `cu129` | NVIDIA driver supporting CUDA 12.9 |

Published images are available at:

```text
ghcr.io/aliceteaparty/vapoursynth-docker:cpu
ghcr.io/aliceteaparty/vapoursynth-docker:cu121
ghcr.io/aliceteaparty/vapoursynth-docker:cu129
```

The CUDA images intentionally use the same small Python base as `cpu`, rather
than an NVIDIA CUDA base image. The selected `vs-mlrt` payload includes its
CUDA, TensorRT, and cuDNN user-mode libraries; the DFTTest2 CUDA payload
includes `cudart` and `cufft`; BM3DCUDA's static-NVRTC plugin needs only the
driver library. At runtime, NVIDIA Container Toolkit supplies `libcuda.so.1`
from the host driver:

```bash
docker run --rm --gpus all ghcr.io/aliceteaparty/vapoursynth-docker:cu129 python -c "import vapoursynth as vs; print(vs.__api_version__)"
```

CUDA image construction and non-GPU smoke checks do not require a GPU. Actual
CUDA/TensorRT filtering needs a compatible NVIDIA driver and GPU.

## Included tools

`ts2_link`, `x265`, `mkvmerge`, `mkvinfo`, `mkvextract`, `tsMuxeR`, `ffmpeg`,
and `ffprobe` are on `PATH`. MkvToolNix is installed from its signed official
Debian repository; the other four downloadable tools use the upstream latest
Release asset selected by `update-tools.sh`.

The build executes the updater once. It remains available in the final image
for a deliberate manual refresh:

```bash
docker run --rm -it --user root ghcr.io/aliceteaparty/vapoursynth-docker:cpu \
  sh -c '$VAPOURSYNTH_DOCKER_ROOT/update-tools.sh'
```

The fixed `ts2-link-v0.4` Release contains exactly one asset named
`ts2_link-v0.4-linux-x86_64.zip` and is never the latest Release. The image
downloads the ZIP, extracts `ts2_link`, and places it on `PATH`. Its source
binary is intentionally not tracked in this repository. Maintainers replace
the single Release asset from their local distribution source before building a
new image.

The VCS plugin builds use an isolated `hatchling<1.32` build constraint.
Hatchling 1.32 changed `BuildHookInterface` from one generic parameter to two,
while the currently published plugin hooks use the prior public interface. The
constraint applies only to temporary PEP 517 build environments and does not
add Hatchling to the final image.

## Local validation

For a local network proxy, pass proxy values only at build time. Do not commit
a local address or port. The following examples use values supplied by the
caller; this repository and CI contain no proxy endpoint.

```bash
docker build --build-arg HTTP_PROXY --build-arg HTTPS_PROXY --build-arg NO_PROXY \
  -f Dockerfile.cpu -t vapoursynth-docker:cpu .
docker run --rm vapoursynth-docker:cpu /usr/local/lib/vapoursynth-docker/smoke-image.sh cpu
```

Build `Dockerfile.cu121` and `Dockerfile.cu129` in the same way. Their
non-GPU smoke check only validates Python and the selected package layout;
run an application filter with `--gpus all` to validate GPU inference.

On pushes to `main` and manual dispatches, the workflow builds and pushes all
three image tags to GHCR. The fixed ts2_link Release asset must already exist.
Pull requests build the same matrix locally in the runner without pushing an
image.
