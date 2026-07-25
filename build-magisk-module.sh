#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="$SCRIPT_DIR/out"
MODULE_DIR="$OUT_DIR/module-content"
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
name=Device Overlays for Redmi A5/POCO C71
version=$BUILD_NUM
versionCode=$BUILD_NUM
author=lunadevph
description=Device-specific overlays for Redmi A5/POCO C71 (serenity) - Core + SystemUI
PROP

# META-INF for Magisk compatibility
META_DIR="$MODULE_DIR/META-INF/com/google/android"
mkdir -p "$META_DIR"
echo '#MAGISK' > "$META_DIR/updater-script"
# update-binary can be empty for Magisk 20.4+
: > "$META_DIR/update-binary"

cd "$MODULE_DIR"
rm -f "$OUT_DIR/$ZIP_NAME"
zip -r "$OUT_DIR/$ZIP_NAME" . -x ".*" > /dev/null
cd "$SCRIPT_DIR"

echo "[+] Magisk module created: $OUT_DIR/$ZIP_NAME"
