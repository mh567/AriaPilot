#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGE_DIR="$ROOT/fnos/package"
SOURCE_DIR="$ROOT/fnos/src"
MANIFEST="$PACKAGE_DIR/manifest"
DIST_DIR="$ROOT/dist"
BUILD_DIR="$ROOT/fnos/build"
FNPACK_VERSION="1.2.3"

ARCH="all"

usage() {
    echo "用法：$0 [--arch x86|arm|all]"
}

while [ $# -gt 0 ]; do
    case "$1" in
    --arch)
        ARCH="${2:-}"
        shift 2
        ;;
    --arch=*)
        ARCH="${1#*=}"
        shift
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        echo "未知参数：$1" >&2
        usage
        exit 1
        ;;
    esac
done

case "$ARCH" in
x86 | arm | all) ;;
*)
    echo "架构必须是 x86、arm 或 all" >&2
    exit 1
    ;;
esac

manifest_value() {
    awk -F '=' -v key="$1" '
        $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
            value = $2
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            print value
            exit
        }
    ' "$MANIFEST"
}

APPNAME="$(manifest_value appname)"
VERSION="$(manifest_value version)"

if [ -z "$APPNAME" ] || [ -z "$VERSION" ]; then
    echo "无法从 manifest 读取 appname 或 version" >&2
    exit 1
fi

md5_file() {
    if command -v md5 >/dev/null 2>&1; then
        md5 -q "$1"
    else
        md5sum "$1" | awk '{print $1}'
    fi
}

resolve_fnpack() {
    if command -v fnpack >/dev/null 2>&1; then
        command -v fnpack
        return 0
    fi

    local cached="$ROOT/.tools/fnpack"
    if [ -x "$cached" ]; then
        echo "$cached"
        return 0
    fi

    if [ "${FNOS_SKIP_FNPACK_DOWNLOAD:-0}" = "1" ]; then
        return 1
    fi

    local os_name
    local arch_name
    case "$(uname -s)" in
    Darwin) os_name="darwin" ;;
    Linux) os_name="linux" ;;
    *) return 1 ;;
    esac
    case "$(uname -m)" in
    x86_64 | amd64) arch_name="amd64" ;;
    arm64 | aarch64) arch_name="arm64" ;;
    *) return 1 ;;
    esac

    mkdir -p "$ROOT/.tools"
    local url="https://static2.fnnas.com/fnpack/fnpack-${FNPACK_VERSION}-${os_name}-${arch_name}"
    echo "下载 fnpack：$url" >&2
    if ! curl -fL --retry 3 --connect-timeout 20 -o "$cached" "$url" >&2; then
        rm -f "$cached"
        return 1
    fi
    chmod 755 "$cached"
    echo "$cached"
}

ensure_aria2() {
    local platform="$1"
    local vendor_dir
    case "$platform" in
    x86) vendor_dir="linux-amd64" ;;
    arm) vendor_dir="linux-arm64" ;;
    esac

    if [ ! -x "$ROOT/vendor/aria2/$vendor_dir/aria2c" ]; then
        bash "$ROOT/scripts/fetch_aria2_linux.sh" "$platform"
    fi

    [ -x "$ROOT/vendor/aria2/$vendor_dir/aria2c" ] || {
        echo "缺少 aria2 二进制：vendor/aria2/$vendor_dir/aria2c" >&2
        exit 1
    }
}

fallback_pack() {
    local stage="$1"
    local platform="$2"

    rm -rf "$stage/app.tgz"
    tar -czf "$stage/app.tgz" -C "$stage/app" .

    local checksum
    checksum="$(md5_file "$stage/app.tgz")"
    if grep -q '^checksum' "$stage/manifest"; then
        sed -i.tmp "s|^checksum.*|checksum              = ${checksum}|" "$stage/manifest"
        rm -f "$stage/manifest.tmp"
    else
        printf 'checksum              = %s\n' "$checksum" >> "$stage/manifest"
    fi

    rm -rf "$stage/app"

    local output="$DIST_DIR/${APPNAME}_${VERSION}_${platform}.fpk"
    (
        cd "$stage"
        tar -czf "$output" manifest cmd config wizard ICON.PNG ICON_256.PNG app.tgz
    )
    echo "$output"
}

validate_fpk() {
    local fpk="$1"
    local platform="$2"
    local listing
    listing="$(tar tzf "$fpk")"

    for required in manifest app.tgz cmd/main config/privilege config/resource wizard/install ICON.PNG ICON_256.PNG; do
        if ! printf '%s\n' "$listing" | grep -Eq "(^|/)${required}$"; then
            echo "FPK 缺少文件：${required}（${fpk}）" >&2
            return 1
        fi
    done

    local tmp
    tmp="$(mktemp -d)"
    tar -xzf "$fpk" -C "$tmp"
    local app_listing
    app_listing="$(tar tzf "$tmp/app.tgz")"
    local packed_platform
    packed_platform="$(
        awk -F '=' '/^platform/{gsub(/[[:space:]]/, "", $2); print $2; exit}' "$tmp/manifest"
    )"
    rm -rf "$tmp"

    for required in server/index.js public/index.html bin/aria2/aria2c ui/config ui/images/icon-64.png; do
        if ! printf '%s\n' "$app_listing" | grep -Eq "(^|/)${required}$"; then
            echo "app.tgz 缺少文件：${required}（${fpk}）" >&2
            return 1
        fi
    done

    if [ "$packed_platform" != "$platform" ]; then
        echo "manifest platform 不匹配：期望 ${platform}，实际 ${packed_platform}" >&2
        return 1
    fi

    return 0
}

build_arch() {
    local platform="$1"
    local vendor_dir
    case "$platform" in
    x86) vendor_dir="linux-amd64" ;;
    arm) vendor_dir="linux-arm64" ;;
    esac

    local stage="$BUILD_DIR/$platform"
    rm -rf "$stage"
    mkdir -p "$stage"

    cp -R "$PACKAGE_DIR/." "$stage/"

    mkdir -p "$stage/app/server" "$stage/app/public" "$stage/app/bin/aria2"
    cp -R "$SOURCE_DIR/public/." "$stage/app/public/"
    cp "$SOURCE_DIR/server/"*.js "$stage/app/server/"
    rm -f "$stage/app/server/"*.test.js
    cp "$ROOT/vendor/aria2/$vendor_dir/aria2c" "$stage/app/bin/aria2/aria2c"
    chmod 755 "$stage/app/bin/aria2/aria2c"

    sed -i.tmp "s|^platform.*|platform              = ${platform}|" "$stage/manifest"
    rm -f "$stage/manifest.tmp"

    local output=""

    local fnpack_bin=""
    if fnpack_bin="$(resolve_fnpack)"; then
        echo "使用 fnpack 打包 ${platform}：$fnpack_bin"
        if (cd "$stage" && "$fnpack_bin" build); then
            local built
            built="$(find "$stage" -maxdepth 1 -type f -name '*.fpk' | head -n 1)"
            if [ -z "$built" ]; then
                built="$(find "$ROOT" -maxdepth 1 -type f -name '*.fpk' -newer "$stage/manifest" | head -n 1)"
            fi
            if [ -n "$built" ]; then
                output="$DIST_DIR/${APPNAME}_${VERSION}_${platform}.fpk"
                mv "$built" "$output"
            fi
        fi
    fi

    if [ -z "$output" ]; then
        echo "fnpack 不可用或未生成 FPK，使用内置打包器（${platform}）"
        output="$(fallback_pack "$stage" "$platform")"
    fi

    [ -f "$output" ] || {
        echo "打包失败：$platform" >&2
        exit 1
    }

    validate_fpk "$output" "$platform"
    echo "已生成：${output}（$(du -h "$output" | cut -f 1)）"
}

mkdir -p "$DIST_DIR" "$BUILD_DIR"
bash "$ROOT/scripts/gen_fnos_icons.sh"

case "$ARCH" in
all)
    ensure_aria2 x86
    ensure_aria2 arm
    build_arch x86
    build_arch arm
    ;;
x86 | arm)
    ensure_aria2 "$ARCH"
    build_arch "$ARCH"
    ;;
esac

echo ""
echo "构建完成，产物位于：$DIST_DIR"
ls -lh "$DIST_DIR"
