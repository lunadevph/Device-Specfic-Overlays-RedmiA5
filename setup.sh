#!/usr/bin/env bash
set -euo pipefail

ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
SDK_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
SDK_DIR="$ANDROID_HOME/cmdline-tools"

echo "[*] Installing Android SDK command-line tools..."

if [ ! -d "$SDK_DIR/tools" ]; then
  mkdir -p "$SDK_DIR"
  curl -fsSL "$SDK_URL" -o /tmp/cmdline-tools.zip
  unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdline-tools
  mv /tmp/cmdline-tools/cmdline-tools "$SDK_DIR/tools"
  rm -rf /tmp/cmdline-tools /tmp/cmdline-tools.zip
fi

export PATH="$SDK_DIR/tools/bin:$PATH"

echo "[*] Accepting licenses..."
yes | sdkmanager --licenses > /dev/null 2>&1 || true

echo "[*] Installing platform android-35 and build-tools..."
sdkmanager "platforms;android-35" "build-tools;35.0.0" > /dev/null

echo "[*] Setup complete."
echo "    ANDROID_HOME=$ANDROID_HOME"
echo "    Add to your shell rc: export ANDROID_HOME=\"$ANDROID_HOME\""
echo "    And: export PATH=\"\$ANDROID_HOME/build-tools/35.0.0:\$PATH\""
