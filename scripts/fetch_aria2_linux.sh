#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="1.36.0"
TAG="1.36.0_2021.08.22"
BASE_URL="https://github.com/P3TERX/Aria2-Pro-Core/releases/download/${TAG}"

TARGET="${1:-all}"

fetch_one() {
    local platform="$1"
    local asset
    local dir

    case "$platform" in
    x86)
        asset="aria2-${VERSION}-static-linux-amd64.tar.gz"
        dir="linux-amd64"
        ;;
    arm)
        asset="aria2-${VERSION}-static-linux-arm64.tar.gz"
        dir="linux-arm64"
        ;;
    *)
        echo "未知架构：${platform}（可选 x86、arm、all）" >&2
        return 1
        ;;
    esac

    local out_dir="$ROOT/vendor/aria2/$dir"
    local target="$out_dir/aria2c"

    if [ -x "$target" ]; then
        echo "已存在：$target"
        return 0
    fi

    mkdir -p "$out_dir" "$ROOT/.tools/aria2"

    local archive="$ROOT/.tools/aria2/$asset"
    local tmp
    tmp="$(mktemp -d)"

    echo "下载 aria2 ${VERSION}（${platform}）：${asset}"
    if ! curl -fL --retry 3 --connect-timeout 20 -o "$archive" "$BASE_URL/$asset"; then
        rm -rf "$tmp"
        return 1
    fi
    if ! tar -xzf "$archive" -C "$tmp"; then
        rm -rf "$tmp"
        rm -f "$archive"
        return 1
    fi

    local found
    found="$(find "$tmp" -type f -name aria2c | head -n 1)"
    if [ -z "$found" ]; then
        echo "解包后未找到 aria2c：${asset}" >&2
        rm -rf "$tmp"
        return 1
    fi

    cp "$found" "$target"
    chmod 755 "$target"
    rm -f "$archive"
    rm -rf "$tmp"

    echo "已安装：$target"
}

case "$TARGET" in
all)
    fetch_one x86
    fetch_one arm
    ;;
x86 | arm)
    fetch_one "$TARGET"
    ;;
*)
    echo "用法：$0 [x86|arm|all]" >&2
    exit 1
    ;;
esac
