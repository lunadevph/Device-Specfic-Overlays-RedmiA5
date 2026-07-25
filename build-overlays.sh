#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
AAPT2="${AAPT2:-$ANDROID_HOME/build-tools/35.0.0/aapt2}"
SDK_JAR="${SDK_JAR:-$ANDROID_HOME/platforms/android-35/android.jar}"

if [ ! -f "$SDK_JAR" ]; then
  SDK_JAR=$(find "$ANDROID_HOME/platforms" -name android.jar 2>/dev/null | head -1 || true)
fi

if [ ! -f "$AAPT2" ]; then
  echo "Error: aapt2 not found at $AAPT2" >&2
  echo "Run setup.sh first or set AAPT2 env var." >&2
  exit 1
fi

if [ ! -x "$AAPT2" ]; then
  echo "Error: aapt2 at $AAPT2 is not executable." >&2
  echo "Run: chmod +x \"$AAPT2\"" >&2
  exit 1
fi

if ! "$AAPT2" version &>/dev/null; then
  echo "Error: aapt2 exists but cannot execute." >&2
  echo "On Alpine musl, install gcompat: sudo apk add gcompat" >&2
  ldd "$AAPT2" 2>/dev/null | head -5 || true
  exit 1
fi

if [ ! -f "$SDK_JAR" ]; then
  echo "Error: android.jar not found. Run setup.sh first or set SDK_JAR." >&2
  exit 1
fi

OUT_DIR="$SCRIPT_DIR/out"
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
