#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/assets/app-icon.svg"
PACKAGE_DIR="$ROOT/fnos/package"
APP_DIR="$PACKAGE_DIR/app"
IMAGES_DIR="$APP_DIR/ui/images"

if [ ! -f "$SOURCE" ]; then
    echo "缺少图标源文件：$SOURCE" >&2
    exit 1
fi

mkdir -p "$PACKAGE_DIR" "$IMAGES_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

render_png() {
    local size="$1"
    local output="$2"

    if command -v rsvg-convert >/dev/null 2>&1; then
        rsvg-convert -w "$size" -h "$size" "$SOURCE" -o "$output"
        return 0
    fi

    if command -v magick >/dev/null 2>&1; then
        magick -background none "$SOURCE" -resize "${size}x${size}" "$output"
        return 0
    fi

    if command -v qlmanage >/dev/null 2>&1; then
        qlmanage -t -s "$size" -o "$TMP_DIR" "$SOURCE" >/dev/null 2>&1 || true
        local produced="$TMP_DIR/app-icon.svg.png"
        if [ -f "$produced" ]; then
            cp "$produced" "$output"
            return 0
        fi
    fi

    echo "无法渲染 SVG 图标，请安装 rsvg-convert 或 ImageMagick" >&2
    return 1
}

render_png 256 "$TMP_DIR/icon-256.png"

if [ ! -s "$TMP_DIR/icon-256.png" ]; then
    echo "图标生成失败" >&2
    exit 1
fi

if command -v sips >/dev/null 2>&1; then
    sips -z 256 256 "$TMP_DIR/icon-256.png" >/dev/null
    cp "$TMP_DIR/icon-256.png" "$TMP_DIR/icon-64.png"
    sips -z 64 64 "$TMP_DIR/icon-64.png" >/dev/null
else
    render_png 64 "$TMP_DIR/icon-64.png"
fi

cp "$TMP_DIR/icon-256.png" "$PACKAGE_DIR/ICON_256.PNG"
cp "$TMP_DIR/icon-64.png" "$PACKAGE_DIR/ICON.PNG"
cp "$TMP_DIR/icon-256.png" "$IMAGES_DIR/icon-256.png"
cp "$TMP_DIR/icon-64.png" "$IMAGES_DIR/icon-64.png"

echo "图标已生成："
echo "  $PACKAGE_DIR/ICON.PNG"
echo "  $PACKAGE_DIR/ICON_256.PNG"
echo "  $IMAGES_DIR/icon-64.png"
echo "  $IMAGES_DIR/icon-256.png"
