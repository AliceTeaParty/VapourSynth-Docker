#!/usr/bin/env bash
set -euo pipefail

readonly TOOL_ROOT=/opt/vapoursynth-tools
readonly TS2_LINK_URL_DEFAULT="https://github.com/AliceTeaParty/VapourSynth-Docker/releases/download/ts2-link-v0.4/ts2_link-v0.4-linux-x86_64.zip"
readonly MKVTOOLNIX_KEY_URL="https://mkvtoolnix.download/gpg-pub-moritzbunkus.gpg"
readonly MKVTOOLNIX_SOURCE="https://mkvtoolnix.download/debian/ bookworm main"

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

main() {
    require_root
    install -d -m 0755 "$TOOL_ROOT"
    install_mkvtoolnix
    install_ts2_link
    install_x265
    install_tsmuxer
    install_ffmpeg
    rm -rf /var/lib/apt/lists/* /root/.cache
}

main "$@"
