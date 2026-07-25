#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="$SCRIPT_DIR/out"
ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
AAPT2="${AAPT2:-$ANDROID_HOME/build-tools/35.0.0/aapt2}"
SDK_JAR="${SDK_JAR:-$ANDROID_HOME/platforms/android-35/android.jar}"

ARCH=$(uname -m)

# --- On aarch64, wrap with box64 if available ---
if [ "$ARCH" != "x86_64" ] && command -v box64 &>/dev/null; then
  RUN_AAPT2="box64 $AAPT2"
  RUN_JAVA="box64 java"
else
  RUN_AAPT2="$AAPT2"
  RUN_JAVA="java"
fi

# --- Try to find android.jar ---
if [ ! -f "$SDK_JAR" ]; then
  SDK_JAR=$(find "$ANDROID_HOME/platforms" -name android.jar 2>/dev/null | head -1 || true)
fi

# --- apktool fallback ---
find_apktool() {
  local cmd
  cmd=$(command -v apktool 2>/dev/null || true)
  if [ -z "$cmd" ] && [ -f "$ANDROID_HOME/apktool" ]; then
    cmd="$ANDROID_HOME/apktool"
  fi
  echo "$cmd"
}

build_with_aapt2() {
  local manifest="$1" resdir="$2" outapk="$3" tmpdir="$4"
  mkdir -p "$tmpdir" "$(dirname "$outapk")"
  $RUN_AAPT2 compile --dir "$resdir" -o "$tmpdir/resources.zip"
  $RUN_AAPT2 link --manifest "$manifest" -I "$SDK_JAR" -o "$outapk" "$tmpdir/resources.zip"
}

build_with_apktool() {
  local manifest="$1" resdir="$2" outapk="$3" pkgname="$4"
  local apktool; apktool=$(find_apktool)
  if [ -z "$apktool" ]; then
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
  $apktool b "$tmpdir" -o "$outapk"
  rm -rf "$tmpdir"
}

# --- Decide which builder to use ---
USE_APKTOOL=0
if [ ! -f "$AAPT2" ]; then
  echo "[*] aapt2 not found — will use apktool"
  USE_APKTOOL=1
elif ! "$AAPT2" version &>/dev/null; then
  echo "[*] aapt2 not executable ($?) — will use apktool"
  USE_APKTOOL=1
elif [ ! -f "$SDK_JAR" ]; then
  echo "[*] android.jar not found — will use apktool"
  USE_APKTOOL=1
fi

if [ "$USE_APKTOOL" = 1 ] && [ -z "$(find_apktool)" ]; then
  echo "[-] Neither aapt2 nor apktool available. Run setup.sh." >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

echo "[*] Building Overlay-Redmi-A5-Core ..."
if [ "$USE_APKTOOL" = 1 ]; then
  build_with_apktool \
    "$SCRIPT_DIR/Overlay-Redmi-A5-Core/AndroidManifest.xml" \
    "$SCRIPT_DIR/Overlay-Redmi-A5-Core/res" \
    "$OUT_DIR/overlay-serenity.apk" \
    "treble-overlay-xiaomi-redmia5"
else
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
fi

echo "[*] Building Overlay-RedmiA5-SystemUI ..."
if [ "$USE_APKTOOL" = 1 ]; then
  build_with_apktool \
    "$SCRIPT_DIR/Overlay-RedmiA5-SystemUI/AndroidManifest.xml" \
    "$SCRIPT_DIR/Overlay-RedmiA5-SystemUI/res" \
    "$OUT_DIR/overlay-serenity-systemui.apk" \
    "treble-overlay-xiaomi-redmia5-systemui"
else
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
fi

echo "[*] Done. APKs in $OUT_DIR/"
ls -1 "$OUT_DIR"/*.apk 2>/dev/null
