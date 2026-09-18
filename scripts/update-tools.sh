#!/usr/bin/env bash
set -euo pipefail

readonly TOOL_ROOT=/opt/vapoursynth-tools
readonly TS2_LINK_URL_DEFAULT="https://github.com/AliceTeaParty/VapourSynth-Docker/releases/download/ts2-link-v0.4/ts2_link-v0.4-linux-x86_64.zip"
readonly MKVTOOLNIX_KEY_URL="https://mkvtoolnix.download/gpg-pub-moritzbunkus.gpg"
readonly MKVTOOLNIX_SOURCE="https://mkvtoolnix.download/debian/ trixie main"
readonly QAAC_VERSION=3.07
readonly QTFILES_VERSION=12.13.9.1
readonly QAAC_HOME=/opt/qaac-wine
readonly QAAC_SHA256=1fb3ab4aa81725e2607ac1b31afa0e13d2617ee6eb5900f5070c092f5271cbb3
readonly QTFILES_SHA256=a81ac9146e8daec8c681e1c8d49548a950f62bb5fe44bdcdaca5aabe3afb3b8f
readonly QTFILES_MSVC_SHA256=3dcc6888507672a27210f9c24568bc5436aef7d72a2d634d4083bbd96fc46daa
readonly FLAC_SHA256=a495efedfc5a352b75fed940e1a11383b74fb93897ff0b29d65f3d68437f71cf

require_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        echo "update-tools.sh must run as root because it updates apt packages." >&2
        exit 1
    fi
}

latest_asset_url() {
    local repository="$1"
    local pattern="$2"
    local release_json asset_url

    release_json="$(curl --fail --location --retry 4 --retry-all-errors --silent --show-error \
        "https://api.github.com/repos/${repository}/releases/latest")"
    asset_url="$(jq -r --arg pattern "$pattern" '
        [.assets[] | select(.name | test($pattern; "i")) | .browser_download_url] | first // empty
    ' <<<"$release_json")"

    if [[ -z "$asset_url" ]]; then
        echo "No release asset matching ${pattern} found for ${repository}." >&2
        return 1
    fi
    printf '%s\n' "$asset_url"
}

download_file() {
    local url="$1"
    local destination="$2"
    curl --fail --location --retry 4 --retry-all-errors --silent --show-error "$url" --output "$destination"
}

download_verified_file() {
    local url="$1"
    local destination="$2"
    local expected_sha256="$3"

    download_file "$url" "$destination"
    echo "${expected_sha256}  ${destination}" | sha256sum --check --status
}

install_mkvtoolnix() {
    apt-get update
    apt-get install -y --no-install-recommends ca-certificates curl
    install -d -m 0755 /usr/share/keyrings
    download_file "$MKVTOOLNIX_KEY_URL" /usr/share/keyrings/mkvtoolnix.gpg
    printf 'deb [signed-by=/usr/share/keyrings/mkvtoolnix.gpg] %s\n' "$MKVTOOLNIX_SOURCE" \
        > /etc/apt/sources.list.d/mkvtoolnix.list

    apt-get update
    apt-get install -y --no-install-recommends \
        bzip2 \
        ca-certificates \
        curl \
        libatomic1 \
        git \
        jq \
        libfftw3-double3 \
        libfftw3-single3 \
        libgl1 \
        libglib2.0-0 \
        libgomp1 \
        libvulkan1 \
        mkvtoolnix \
        ocl-icd-libopencl1 \
        unzip \
        xz-utils
}

install_ts2_link() {
    local url="${TS2_LINK_URL:-$TS2_LINK_URL_DEFAULT}"
    local work_dir
    work_dir="$(mktemp -d)"
    download_file "$url" "${work_dir}/ts2_link.zip"
    unzip -q -o "${work_dir}/ts2_link.zip" -d "${work_dir}/unpack"
    install -m 0755 "$(find "${work_dir}/unpack" -type f -name ts2_link -print -quit)" "${TOOL_ROOT}/ts2_link"
    ln -sf "${TOOL_ROOT}/ts2_link" /usr/local/bin/ts2_link
    rm -rf "$work_dir"
}

install_x265() {
    local archive work_dir
    work_dir="$(mktemp -d)"
    archive="${work_dir}/x265.tar.xz"
    download_file "$(latest_asset_url RyougiKukoc/x265-Linux-nightly-build '^x265-linux-x86_64-glibc.*\.tar\.xz$')" "$archive"
    tar -xJf "$archive" -C "$work_dir"
    install -m 0755 "$(find "$work_dir" -type f -name x265 -print -quit)" "${TOOL_ROOT}/x265"
    ln -sf "${TOOL_ROOT}/x265" /usr/local/bin/x265
    rm -rf "$work_dir"
}

install_tsmuxer() {
    local archive work_dir
    work_dir="$(mktemp -d)"
    archive="${work_dir}/tsmuxer.zip"
    download_file "$(latest_asset_url justdan96/tsMuxer '^tsMuxer-[0-9.]+-linux\.zip$')" "$archive"
    unzip -q -o "$archive" -d "$work_dir/unpack"
    install -m 0755 "$(find "$work_dir/unpack" -type f -name tsMuxeR -print -quit)" "${TOOL_ROOT}/tsMuxeR"
    ln -sf "${TOOL_ROOT}/tsMuxeR" /usr/local/bin/tsMuxeR
    rm -rf "$work_dir"
}

install_ffmpeg() {
    local archive ffmpeg_path ffprobe_path work_dir
    work_dir="$(mktemp -d)"
    archive="${work_dir}/ffmpeg.tar.xz"
    download_file "$(latest_asset_url Vodes/FFmpeg-Builds '^ffmpeg-.*-linux64-nonfree.*\.tar\.xz$')" "$archive"
    tar -xJf "$archive" -C "$work_dir"
    ffmpeg_path="$(find "$work_dir" -type f -name ffmpeg -print -quit)"
    ffprobe_path="$(find "$work_dir" -type f -name ffprobe -print -quit)"
    install -m 0755 "$ffmpeg_path" "${TOOL_ROOT}/ffmpeg"
    install -m 0755 "$ffprobe_path" "${TOOL_ROOT}/ffprobe"
    ln -sf "${TOOL_ROOT}/ffmpeg" /usr/local/bin/ffmpeg
    ln -sf "${TOOL_ROOT}/ffprobe" /usr/local/bin/ffprobe
    rm -rf "$work_dir"
}

install_qaac64() (
    local tmp_dir test_prefix
    local required_files=(
        ASL.dll
        concrt140.dll
        CoreAudioToolbox.dll
        CoreFoundation.dll
        icudt62.dll
        libdispatch.dll
        libFLAC_dynamic.dll
        libicuin.dll
        libicuuc.dll
        libsoxr64.dll
        msvcp140.dll
        msvcp140_1.dll
        msvcp140_2.dll
        msvcp140_atomic_wait.dll
        msvcp140_codecvt_ids.dll
        objc.dll
        qaac64.exe
        vccorlib140.dll
        vcruntime140.dll
        vcruntime140_1.dll
        vcruntime140_threads.dll
    )

    if [[ "$(dpkg --print-architecture)" != amd64 ]]; then
        echo "qaac64 requires an amd64 image." >&2
        return 1
    fi

    dpkg --add-architecture i386
    apt-get -o Acquire::Retries=3 update
    apt-get -o Acquire::Retries=3 install -y --no-install-recommends wine wine64 wine32:i386 7zip

    tmp_dir="$(mktemp -d)"
    test_prefix="$(mktemp -d)"
    cleanup_qaac() {
        WINEPREFIX="$test_prefix" wineserver -k >/dev/null 2>&1 || true
        rm -rf "$tmp_dir" "$test_prefix"
    }
    trap cleanup_qaac EXIT

    download_verified_file \
        "https://github.com/nu774/qaac/releases/download/v${QAAC_VERSION}/qaac_${QAAC_VERSION}.zip" \
        "$tmp_dir/qaac.zip" \
        "$QAAC_SHA256"
    download_verified_file \
        "https://github.com/AnimMouse/QTFiles/releases/download/v${QTFILES_VERSION}/QTfiles64.7z" \
        "$tmp_dir/qtfiles64.7z" \
        "$QTFILES_SHA256"
    download_verified_file \
        "https://github.com/AnimMouse/QTFiles/releases/download/v${QTFILES_VERSION}/QTfiles64-MSVC.7z" \
        "$tmp_dir/qtfiles64-msvc.7z" \
        "$QTFILES_MSVC_SHA256"
    download_verified_file \
        "https://www.rarewares.org/files/lossless/flac-dynamic_dll-1.5.0-x64.zip" \
        "$tmp_dir/flac.zip" \
        "$FLAC_SHA256"

    rm -rf "$QAAC_HOME"
    install -d -m 0755 "$QAAC_HOME"
    7z x -bd -y "-o${tmp_dir}/qaac" "$tmp_dir/qaac.zip" >/dev/null
    install -m 0755 "$tmp_dir/qaac/qaac_${QAAC_VERSION}/x64/qaac64.exe" "$QAAC_HOME/qaac64.exe"
    install -m 0644 "$tmp_dir/qaac/qaac_${QAAC_VERSION}/x64/libsoxr64.dll" "$QAAC_HOME/libsoxr64.dll"
    7z x -bd -y "-o${QAAC_HOME}" "$tmp_dir/qtfiles64.7z" >/dev/null
    7z x -bd -y "-o${QAAC_HOME}" "$tmp_dir/qtfiles64-msvc.7z" >/dev/null
    7z x -bd -y "-o${tmp_dir}/flac" "$tmp_dir/flac.zip" >/dev/null
    install -m 0644 "$tmp_dir/flac/libFLAC_dynamic.dll" "$QAAC_HOME/libFLAC_dynamic.dll"

    for file in "${required_files[@]}"; do
        [[ -f "$QAAC_HOME/$file" ]] || { echo "Missing qaac runtime file: $file" >&2; return 1; }
    done

    cat > /usr/local/bin/qaac64 <<'EOF'
#!/bin/sh
set -eu

: "${WINEDEBUG:=-all}"
export WINEDEBUG

if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
    XDG_RUNTIME_DIR="${TMPDIR:-/tmp}/qaac-wine-runtime-$(id -u)"
    mkdir -p -m 700 "$XDG_RUNTIME_DIR"
    export XDG_RUNTIME_DIR
fi

export WINEDLLOVERRIDES="concrt140,msvcp140,msvcp140_1,msvcp140_2,msvcp140_atomic_wait,msvcp140_codecvt_ids,vccorlib140,vcruntime140,vcruntime140_1,vcruntime140_threads=n;${WINEDLLOVERRIDES:-}"
exec /usr/bin/wine /opt/qaac-wine/qaac64.exe "$@"
EOF
    chmod 0755 /usr/local/bin/qaac64

    mkdir -p -m 700 "$test_prefix/runtime"
    WINEPREFIX="$test_prefix" WINEARCH=win64 XDG_RUNTIME_DIR="$test_prefix/runtime" qaac64 --check
)

main() {
    require_root
    install -d -m 0755 "$TOOL_ROOT"
    install_mkvtoolnix
    install_ts2_link
    install_x265
    install_tsmuxer
    install_ffmpeg
    install_qaac64
    rm -rf /var/lib/apt/lists/* /root/.cache
}

main "$@"
