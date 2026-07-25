#!/usr/bin/env bash
set -euo pipefail

ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
SDK_DIR="$ANDROID_HOME/cmdline-tools"

# --- Distro detection & package install ---
detect_distro() {
  if command -v apt &>/dev/null; then echo "debian"
  elif command -v dnf &>/dev/null; then echo "fedora"
  elif command -v yum &>/dev/null; then echo "rhel"
  elif command -v pacman &>/dev/null; then echo "arch"
  elif command -v apk &>/dev/null; then echo "alpine"
  elif command -v xbps-install &>/dev/null; then echo "void"
  elif command -v zypper &>/dev/null; then echo "opensuse"
  else echo "unknown"
  fi
}

distro_install() {
  local d="$1"
  shift
  case "$d" in
    debian)
      sudo apt update
      sudo apt install -y "$@"
      ;;
    fedora)
      sudo dnf install -y "$@"
      ;;
    rhel)
      sudo yum install -y "$@"
      ;;
    arch)
      sudo pacman -Sy --noconfirm "$@"
      ;;
    alpine)
      sudo apk add "$@"
      ;;
    void)
      sudo xbps-install -Sy "$@"
      ;;
    opensuse)
      sudo zypper install -y "$@"
      ;;
  esac
}

ARCH=$(uname -m)
DISTRO=$(detect_distro)
echo "[*] Detected distro: $DISTRO  |  Arch: $ARCH"

if [ "$ARCH" != "x86_64" ]; then
  echo "[-] aapt2 (Android build-tools) is only available for x86_64." >&2
  echo "    Your arch is $ARCH — install aapt2 manually or use an x86_64 machine." >&2
  exit 1
fi

# --- Map package names per distro ---
case "$DISTRO" in
  debian)   PKG_JAVA="openjdk-17-jdk"     PKG_GLIBC=""                 PKG_OTHER="curl unzip" ;;
  fedora|rhel) PKG_JAVA="java-17-openjdk" PKG_GLIBC=""                 PKG_OTHER="curl unzip" ;;
  arch)     PKG_JAVA="jdk17-openjdk"      PKG_GLIBC=""                 PKG_OTHER="curl unzip" ;;
  alpine)   PKG_JAVA="openjdk17"          PKG_GLIBC="gcompat"          PKG_OTHER="curl unzip" ;;
  void)     PKG_JAVA="openjdk17-jdk"      PKG_GLIBC=""                 PKG_OTHER="curl unzip" ;;
  opensuse) PKG_JAVA="java-17-openjdk"    PKG_GLIBC=""                 PKG_OTHER="curl unzip" ;;
  *)
    echo "[-] Unsupported distro. Install java-17, curl, and unzip manually." >&2
    exit 1
    ;;
esac

# --- Install missing prerequisites ---
MISSING=""
command -v java    &>/dev/null || MISSING+=" $PKG_JAVA"
command -v curl    &>/dev/null || MISSING+=" curl"
command -v unzip   &>/dev/null || MISSING+=" unzip"
command -v zip     &>/dev/null || MISSING+=" zip"
# On Alpine musl, aapt2 needs glibc compat
if [ "$DISTRO" = "alpine" ]; then
  command -v gcompat &>/dev/null || MISSING+=" $PKG_GLIBC"
fi

if [ -n "$MISSING" ]; then
  echo "[*] Installing missing packages:$MISSING"
  # shellcheck disable=SC2086
  distro_install "$DISTRO" $MISSING
fi

echo "[+] Java: $(java -version 2>&1 | head -1)"

# --- Install Android cmdline-tools ---
if [ -d "$SDK_DIR/tools" ]; then
  echo "[*] cmdline-tools already installed at $SDK_DIR/tools"
else
  echo "[*] Downloading Android SDK command-line tools..."
  mkdir -p "$SDK_DIR"
  LATEST=$(curl -fsS https://developer.android.com/studio \
    | grep -oP 'commandlinetools-linux-\d+_latest\.zip' \
    | head -1 || echo "commandlinetools-linux-11076708_latest.zip")
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
