# VapourSynth Docker

Three Linux x86_64 images provide a Python 3.13 VapourSynth R81+ API4 environment
for encode work. They use `python:3.13-slim-trixie`, whose current libstdc++
supports the GLIBCXX ABI required by the cu129 TensorRT payload. They contain
one system-level Python installation and do not use Conda. `python` is an
explicit symlink to that same `python3` interpreter, and `python3` is the image
entrypoint.

| Image tag | Variant packages | GPU requirement |
| --- | --- | --- |
| `generic` | `vapoursynth-bm3dcpu`, `vapoursynth-dfttest2-cpu`, `vs-mlrt-generic` | None |
| `cu121` | BM3DCUDA, DFTTest2, and vs-mlrt `cu121` wheels | NVIDIA driver supporting CUDA 12.1 |
| `cu129` | BM3DCUDA, DFTTest2, and vs-mlrt `cu129` wheels | NVIDIA driver supporting CUDA 12.9 |

The `generic` tag is the CUDA-free variant. It deliberately omits
`vapoursynth-vszipcu`, the CUDA payload of vszip, which needs an NVIDIA GPU and
NVRTC at runtime; the CPU
`vapoursynth-vszip` and OpenCL `vapoursynth-vszipcl` payloads are installed in
all three images.

All variants include BM3DVK2, KrigBilateralVK and DFTTestVK, following the
[API4 environment guide](https://github.com/AliceTeaParty/How-to-Create-an-Environment/blob/main/%40plugin-api4.md).
KrigBilateralVK and DFTTestVK require a Vulkan 1.4 device/driver for rendering.
The Vulkan loader is installed in the image; the device and vendor driver must
be exposed by the host. CUDA compatibility alone does not guarantee Vulkan
availability in a container. CPU filters remain usable without a GPU.

Published images are available at:

```text
ghcr.io/aliceteaparty/vapoursynth-docker:generic
ghcr.io/aliceteaparty/vapoursynth-docker:cu121
ghcr.io/aliceteaparty/vapoursynth-docker:cu129
```

Each publish produces exactly six tags: the three floating compatibility tags
above and one immutable 12-character source tag per line, such as
`generic-7c05a2f12345`. The floating tags always move to the newest image in
their respective compatibility line.
This is a public GHCR package. GitHub's current Container registry policy
makes container-image storage and bandwidth free; no automatic image-deletion
job is configured. Reassess this choice if GitHub changes that policy.

The CUDA images intentionally use the same small Python base as `generic`,
rather than an NVIDIA CUDA base image. The selected `vs-mlrt` payload includes
its CUDA, TensorRT, and cuDNN user-mode libraries; the DFTTest2 CUDA payload
includes `cudart` and `cufft`; BM3DCUDA's static-NVRTC plugin needs only the
driver library. At runtime, NVIDIA Container Toolkit supplies `libcuda.so.1`
from the host driver:

```bash
docker run --rm --gpus all ghcr.io/aliceteaparty/vapoursynth-docker:cu129 \
  -c "import vapoursynth as vs; print(vs.__api_version__)"
```

CUDA image construction and non-GPU smoke checks do not require a GPU. Actual
CUDA/TensorRT filtering needs a compatible NVIDIA driver and GPU.

## Included tools

`ts2_link`, `x265`, `mkvmerge`, `mkvinfo`, `mkvextract`, `tsMuxeR`, `ffmpeg`,
`ffprobe`, and `qaac64` are on `PATH`. The `vs-mlrt-cu129` wheel supplies its
matching TensorRT 11.1 engine builder and runtime components. MkvToolNix is
installed from its signed official Debian repository; the other downloadable
tools use the upstream latest Release asset selected by `update-tools.sh`.

`qaac64` runs the upstream Windows binary through Wine because qaac has no
native Linux runtime. The image installs Wine's amd64 and i386 support
runtimes, qaac 3.07, pinned QTFiles QuickTime/MSVC DLL archives, and the
RareWares FLAC DLL. Every external qaac artifact has a pinned SHA-256 and the
build runs `qaac64 --check` in an ephemeral Wine prefix. The runtime files stay
in `/opt/qaac-wine`; no Wine prefix is embedded in the image.

The build executes the updater once. It remains available in the final image
for a deliberate manual refresh:

```bash
docker run --rm -it --user root --entrypoint sh \
  ghcr.io/aliceteaparty/vapoursynth-docker:generic \
  -c '$VAPOURSYNTH_DOCKER_ROOT/update-tools.sh'
```

The fixed `ts2-link-v0.4` Release contains exactly one asset named
`ts2_link-v0.4-linux-x86_64.zip` and is never the latest Release. The image
downloads the ZIP, extracts `ts2_link`, and places it on `PATH`. Its source
binary is intentionally not tracked in this repository. Maintainers replace
the single Release asset from their local distribution source before building a
new image.

Maintained API4 ports are installed as prebuilt wheels from the
[`vapoursynth-api4-wheels`](https://github.com/AliceTeaParty/vapoursynth-api4-wheels)
package index. The snapshot in `scripts/requirements-api4-*.txt` keeps exact
published versions, including `+alice.1` for modified upstream packages, so pip
cannot select a different same-name PyPI package. KrigBilateralVK `0.4.1` and
DFTTestVK `0.1.0` keep their original versions. The three vs-mlrt entries use
`16.2.6+alice.1` and their component/model dependencies use `16.2.2+alice.1`;
BM3D uses `2.16+alice.1` and DFTTest2 uses `10.2+alice.1` in each CUDA/CPU line.

`rksfunc`, `rkstool`, and `vs-collection-rk` are installed as wheels using only
the api4-wheels index, without version pins. The Collection entry installs its
separately packaged, version-pinned components. Other script dependencies
(`getnative`, `awsmfunc`, and `vsjetpack`) continue to come from PyPI.
Build and runtime checks also resolve rkstool's default tsMuxeR executable on
`PATH`, covering the Linux executable-name fix published in rkstool 1.1.4.

TIVTC, Bifrost and BM3DVK2 use the upstream PyPI wheels, as in the environment
guide. The former TIVTC/Bifrost VCS builds and their Hatchling constraint are
no longer needed.

## Local validation

For a local network proxy, pass proxy values only at build time. Do not commit
a local address or port. The following examples use values supplied by the
caller; this repository and CI contain no proxy endpoint.

```bash
docker build --build-arg HTTP_PROXY --build-arg HTTPS_PROXY --build-arg NO_PROXY \
  -f Dockerfile.generic -t vapoursynth-docker:generic .
docker run --rm \
  --entrypoint /usr/local/lib/vapoursynth-docker/smoke-image.sh \
  vapoursynth-docker:generic generic
```

Build `Dockerfile.cu121` and `Dockerfile.cu129` in the same way. Their
non-GPU smoke check only validates Python and the selected package layout;
run an application filter with `--gpus all` to validate GPU inference.

On pushes to `main` and manual dispatches, the workflow builds and pushes all
three image tags to GHCR. The fixed ts2_link Release asset must already exist.
Pull requests build the same matrix locally in the runner without pushing an
image. Both builds and runtime smoke tests check the installed API4 versions,
script wheel provenance, Collection component versions, and vs-mlrt layout.
The generic smoke also checks the new Vulkan plugin namespaces and renders
frames through BM3D's CPU backend, TIVTC and Bifrost. This checks Vulkan plugin
loading; rendering with Vulkan still requires a suitable device and driver.
After publication, fresh jobs pull each immutable tag anonymously from GHCR
and repeat the runtime checks. Optional Docker build-record artifact uploads
are disabled; build logs and job summaries remain available.
