#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="$SCRIPT_DIR/out"
ARCH=$(uname -m)

build_with_aapt2() {
  local manifest="$1"
  local resdir="$2"
  local outapk="$3"
  local tmpdir="$4"

  ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
  AAPT2="${AAPT2:-$ANDROID_HOME/build-tools/35.0.0/aapt2}"
  SDK_JAR="${SDK_JAR:-$ANDROID_HOME/platforms/android-35/android.jar}"

  if [ ! -f "$SDK_JAR" ]; then
    SDK_JAR=$(find "$ANDROID_HOME/platforms" -name android.jar 2>/dev/null | head -1 || true)
  fi

  if [ ! -f "$AAPT2" ]; then
    echo "Error: aapt2 not found at $AAPT2" >&2
    echo "Run setup.sh first or set AAPT2 env var." >&2
    return 1
  fi

  if ! "$AAPT2" version &>/dev/null; then
    echo "Error: aapt2 exists but cannot execute" >&2
    echo "On Alpine: apk add gcompat libc6-compat && sudo ln -sf /lib/ld-linux-x86-64.so.2 /lib64/" >&2
    ldd "$AAPT2" 2>/dev/null | head -3 || true
    return 1
  fi

  if [ ! -f "$SDK_JAR" ]; then
    echo "Error: android.jar not found. Run setup.sh first." >&2
    return 1
  fi

  mkdir -p "$tmpdir" "$(dirname "$outapk")"
  "$AAPT2" compile --dir "$resdir" -o "$tmpdir/resources.zip"
  "$AAPT2" link --manifest "$manifest" -I "$SDK_JAR" -o "$outapk" "$tmpdir/resources.zip"
}

build_with_apktool() {
  local manifest="$1"
  local resdir="$2"
  local outapk="$3"
  local pkgname="$4"

  if ! command -v apktool &>/dev/null; then
    echo "Error: apktool not found. Run setup.sh first." >&2
    return 1
  fi

  local tmpdir="$OUT_DIR/apktool-work/$pkgname"
  rm -rf "$tmpdir"
  mkdir -p "$tmpdir"

  cp "$manifest" "$tmpdir/AndroidManifest.xml"
  cp -r "$resdir" "$tmpdir/res/"

  cat > "$tmpdir/apktool.yml" << YML
!!brut.androlib.meta.MetaInfo
apkFileName: $pkgname.apk
compressionType: false
isSharedLibrary: false
sdkInfo:
  minSdkVersion: '35'
  targetSdkVersion: '35'
packageInfo:
  forcedPackageId: '127'
  renameManifestPackage: null
versionInfo:
  versionCode: '1'
  versionName: '1.0'
resourcesAreCompressed: false
YML

  apktool b "$tmpdir" -o "$outapk"
  rm -rf "$tmpdir"
}

mkdir -p "$OUT_DIR"

echo "[*] Building Overlay-Redmi-A5-Core ..."
if [ "$ARCH" = "x86_64" ]; then
  build_with_aapt2 \
    "$SCRIPT_DIR/Overlay-Redmi-A5-Core/AndroidManifest.xml" \
    "$SCRIPT_DIR/Overlay-Redmi-A5-Core/res" \
    "$OUT_DIR/overlay-serenity.apk" \
    "$OUT_DIR/core" || {
      echo "[-] aapt2 failed, falling back to apktool..."
      build_with_apktool \
        "$SCRIPT_DIR/Overlay-Redmi-A5-Core/AndroidManifest.xml" \
        "$SCRIPT_DIR/Overlay-Redmi-A5-Core/res" \
        "$OUT_DIR/overlay-serenity.apk" \
        "treble-overlay-xiaomi-redmia5"
    }
else
  build_with_apktool \
    "$SCRIPT_DIR/Overlay-Redmi-A5-Core/AndroidManifest.xml" \
    "$SCRIPT_DIR/Overlay-Redmi-A5-Core/res" \
    "$OUT_DIR/overlay-serenity.apk" \
    "treble-overlay-xiaomi-redmia5"
fi

echo "[*] Building Overlay-RedmiA5-SystemUI ..."
if [ "$ARCH" = "x86_64" ]; then
  build_with_aapt2 \
    "$SCRIPT_DIR/Overlay-RedmiA5-SystemUI/AndroidManifest.xml" \
    "$SCRIPT_DIR/Overlay-RedmiA5-SystemUI/res" \
    "$OUT_DIR/overlay-serenity-systemui.apk" \
    "$OUT_DIR/systemui" || {
      echo "[-] aapt2 failed, falling back to apktool..."
      build_with_apktool \
        "$SCRIPT_DIR/Overlay-RedmiA5-SystemUI/AndroidManifest.xml" \
        "$SCRIPT_DIR/Overlay-RedmiA5-SystemUI/res" \
        "$OUT_DIR/overlay-serenity-systemui.apk" \
        "treble-overlay-xiaomi-redmia5-systemui"
    }
else
  build_with_apktool \
    "$SCRIPT_DIR/Overlay-RedmiA5-SystemUI/AndroidManifest.xml" \
    "$SCRIPT_DIR/Overlay-RedmiA5-SystemUI/res" \
    "$OUT_DIR/overlay-serenity-systemui.apk" \
    "treble-overlay-xiaomi-redmia5-systemui"
fi

echo "[*] Done. APKs in $OUT_DIR/"
ls -1 "$OUT_DIR"/*.apk 2>/dev/null
