#!/usr/bin/env bash
set -euo pipefail

readonly TENSORRT_VERSION=11.1.0.106-1+cuda12.9
readonly TENSORRT_REPOSITORY=https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64
readonly TENSORRT_ROOT=/opt/tensorrt-11.1
readonly TENSORRT_BIN_SHA256=1d6ab43edece55c481668cd172cfc3f2160f34ad2f3c4f0d263fe332ed0b16ab
readonly TENSORRT_PLUGIN_SHA256=9a98bc3d6f5270dfc1bccf4a1f7d038e2a19e98141022d9b7d4682c431a2d16b
readonly TENSORRT_RUNTIME_SHA256=e1a0d4e11d8b3c7b72e44b1b3cd1ab943aab41f43b11f667ad5afda91cf1b6ca
readonly VSMLRT_PLUGIN_ROOT=/usr/local/lib/python3.13/site-packages/vapoursynth/plugins/vsmlrt

if [[ "$(id -u)" -ne 0 ]]; then
    echo "install-tensorrt-builder.sh must run as root." >&2
    exit 1
fi
if [[ "$(dpkg --print-architecture)" != amd64 ]]; then
    echo "TensorRT builder installation requires amd64." >&2
    exit 1
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
bin_deb="$work_dir/libnvinfer-bin.deb"
plugin_deb="$work_dir/libnvinfer-plugin11.deb"
runtime_deb="$work_dir/libnvinfer11.deb"

curl --fail --location --retry 4 --retry-all-errors --silent --show-error \
    "$TENSORRT_REPOSITORY/libnvinfer-bin_${TENSORRT_VERSION}_amd64.deb" \
    --output "$bin_deb"
echo "$TENSORRT_BIN_SHA256  $bin_deb" | sha256sum --check --status
curl --fail --location --retry 4 --retry-all-errors --silent --show-error \
    "$TENSORRT_REPOSITORY/libnvinfer-plugin11_${TENSORRT_VERSION}_amd64.deb" \
    --output "$plugin_deb"
echo "$TENSORRT_PLUGIN_SHA256  $plugin_deb" | sha256sum --check --status
curl --fail --location --retry 4 --retry-all-errors --silent --show-error \
    "$TENSORRT_REPOSITORY/libnvinfer11_${TENSORRT_VERSION}_amd64.deb" \
    --output "$runtime_deb"
echo "$TENSORRT_RUNTIME_SHA256  $runtime_deb" | sha256sum --check --status

dpkg-deb --extract "$bin_deb" "$work_dir/root"
dpkg-deb --extract "$plugin_deb" "$work_dir/root"
dpkg-deb --extract "$runtime_deb" "$work_dir/root"
install -d -m 0755 "$TENSORRT_ROOT/bin" "$TENSORRT_ROOT/lib"
install -m 0755 "$work_dir/root/usr/bin/trtexec" "$TENSORRT_ROOT/bin/trtexec"
cp -a "$work_dir/root/usr/lib/x86_64-linux-gnu/." "$TENSORRT_ROOT/lib/"

cat > /usr/local/bin/trtexec <<'EOF'
#!/bin/sh
set -eu

: "${VSMLRT_PLUGIN_ROOT:=/usr/local/lib/python3.13/site-packages/vapoursynth/plugins/vsmlrt}"
export LD_LIBRARY_PATH="/opt/tensorrt-11.1/lib:${VSMLRT_PLUGIN_ROOT}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
exec /opt/tensorrt-11.1/bin/trtexec "$@"
EOF
chmod 0755 /usr/local/bin/trtexec
install -d -m 0755 "$VSMLRT_PLUGIN_ROOT/vsmlrt-cuda"
ln -sfn /usr/local/bin/trtexec "$VSMLRT_PLUGIN_ROOT/vsmlrt-cuda/trtexec"

test -x "$TENSORRT_ROOT/bin/trtexec"
test -f "$TENSORRT_ROOT/lib/libnvinfer_plugin.so.11.1.0"
test -f "$TENSORRT_ROOT/lib/libnvinfer_builder_resource_sm86.so.11.1.0"
test -x /usr/local/bin/trtexec
test -x "$VSMLRT_PLUGIN_ROOT/vsmlrt-cuda/trtexec"
