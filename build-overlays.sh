#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="$SCRIPT_DIR/out"
ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
AAPT2="${AAPT2:-$ANDROID_HOME/build-tools/35.0.0/aapt2}"
SDK_JAR="${SDK_JAR:-$ANDROID_HOME/platforms/android-35/android.jar}"

if [ ! -f "$SDK_JAR" ]; then
  SDK_JAR=$(find "$ANDROID_HOME/platforms" -name android.jar 2>/dev/null | head -1 || true)
fi

if [ ! -f "$AAPT2" ]; then
  echo "[-] aapt2 not found at $AAPT2 — run setup.sh" >&2
  exit 1
fi

if ! "$AAPT2" version &>/dev/null; then
  echo "[-] aapt2 cannot execute — local builds require x86_64" >&2
  echo "    Use GitHub Actions CI instead." >&2
  exit 1
fi

if [ ! -f "$SDK_JAR" ]; then
  echo "[-] android.jar not found — run setup.sh" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

echo "[*] Building Overlay-Redmi-A5-Core ..."
mkdir -p "$OUT_DIR/core"
"$AAPT2" compile --dir "$SCRIPT_DIR/Overlay-Redmi-A5-Core/res" -o "$OUT_DIR/core/resources.zip"
"$AAPT2" link --manifest "$SCRIPT_DIR/Overlay-Redmi-A5-Core/AndroidManifest.xml" \
  -I "$SDK_JAR" -o "$OUT_DIR/overlay-serenity.apk" "$OUT_DIR/core/resources.zip"

echo "[*] Building Overlay-RedmiA5-SystemUI ..."
mkdir -p "$OUT_DIR/systemui"
"$AAPT2" compile --dir "$SCRIPT_DIR/Overlay-RedmiA5-SystemUI/res" -o "$OUT_DIR/systemui/resources.zip"
"$AAPT2" link --manifest "$SCRIPT_DIR/Overlay-RedmiA5-SystemUI/AndroidManifest.xml" \
  -I "$SDK_JAR" -o "$OUT_DIR/overlay-serenity-systemui.apk" "$OUT_DIR/systemui/resources.zip"

echo "[*] Done. APKs in $OUT_DIR/"
ls -1 "$OUT_DIR"/*.apk 2>/dev/null
