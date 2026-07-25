#!/usr/bin/env bash
set -euo pipefail

ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
SDK_DIR="$ANDROID_HOME/cmdline-tools"

echo "[*] Checking prerequisites..."

if ! command -v java &>/dev/null; then
  echo "[-] Java not found. Install JDK 17+ first." >&2
  echo "    Ubuntu/Debian: sudo apt install openjdk-17-jdk" >&2
  exit 1
fi

if ! command -v curl &>/dev/null; then
  echo "[-] curl not found. Install it first." >&2
  exit 1
fi

if ! command -v unzip &>/dev/null; then
  echo "[-] unzip not found. Install it first." >&2
  exit 1
fi

echo "[+] Java: $(java -version 2>&1 | head -1)"

if [ -d "$SDK_DIR/tools" ]; then
  echo "[*] cmdline-tools already installed at $SDK_DIR/tools"
else
  echo "[*] Downloading Android SDK command-line tools..."
  mkdir -p "$SDK_DIR"
  LATEST=$(curl -fsS https://developer.android.com/studio | grep -oP 'commandlinetools-linux-\d+_latest\.zip' | head -1 || echo "commandlinetools-linux-11076708_latest.zip")
  URL="https://dl.google.com/android/repository/$LATEST"
  curl -fSL "$URL" -o /tmp/cmdline-tools.zip
  unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdline-tools-extracted
  mkdir -p "$SDK_DIR/tools"
  mv /tmp/cmdline-tools-extracted/cmdline-tools/* "$SDK_DIR/tools/"
  rm -rf /tmp/cmdline-tools.zip /tmp/cmdline-tools-extracted
  echo "[+] cmdline-tools installed"
fi

export PATH="$SDK_DIR/tools/bin:$PATH"

echo "[*] Accepting licenses..."
yes | sdkmanager --licenses > /dev/null 2>&1 || true

echo "[*] Installing platform android-35 and build-tools..."
sdkmanager "platforms;android-35" "build-tools;35.0.0" > /dev/null

echo "[+] Setup complete."
echo "    ANDROID_HOME=$ANDROID_HOME"
echo ""
echo "    Run this or add to your shell rc:"
echo "    export ANDROID_HOME=\"$ANDROID_HOME\""
echo "    export PATH=\"\$ANDROID_HOME/build-tools/35.0.0:\$PATH\""
