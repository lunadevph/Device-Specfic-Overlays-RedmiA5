#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="$SCRIPT_DIR/out"
MODULE_DIR="$OUT_DIR/module"
MODULE_SYSTEM="$MODULE_DIR/system/product/overlay"
MODULE_NAME="serenity-overlays"
ZIP_NAME="${MODULE_NAME}.zip"
BUILD_NUM="${1:-1}"

if [ ! -f "$OUT_DIR/overlay-serenity.apk" ] || [ ! -f "$OUT_DIR/overlay-serenity-systemui.apk" ]; then
  echo "[-] APKs not found. Run 'make overlays' first." >&2
  exit 1
fi

rm -rf "$MODULE_DIR"
mkdir -p "$MODULE_SYSTEM"

cp "$OUT_DIR/overlay-serenity.apk" "$MODULE_SYSTEM/treble-overlay-xiaomi-redmia5.apk"
cp "$OUT_DIR/overlay-serenity-systemui.apk" "$MODULE_SYSTEM/treble-overlay-xiaomi-redmia5-systemui.apk"

cat > "$MODULE_DIR/module.prop" << PROP
id=$MODULE_NAME
name=Serenity Overlays for Redmi A5
version=$BUILD_NUM
versionCode=$BUILD_NUM
author=lunadevph
description=Device-specific overlays for Redmi A5 (serenity) - Core + SystemUI
PROP

cd "$OUT_DIR"
rm -f "$ZIP_NAME"
zip -r "$ZIP_NAME" module/ -x ".*" > /dev/null
cd "$SCRIPT_DIR"

echo "[+] Magisk module created: $OUT_DIR/$ZIP_NAME"
