#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

swift "$ROOT/scripts/generate_app_icon.swift"
iconutil -c icns "$ROOT/assets/AppIcon.iconset" -o "$ROOT/assets/AppIcon.icns"

echo "Created $ROOT/assets/AppIcon.icns"
