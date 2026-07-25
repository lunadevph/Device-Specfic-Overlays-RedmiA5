#!/usr/bin/env bash
set -euo pipefail

ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
SDK_DIR="$ANDROID_HOME/cmdline-tools"

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
    debian) sudo apt update && sudo apt install -y "$@" ;;
    fedora) sudo dnf install -y "$@" ;;
    rhel)   sudo yum install -y "$@" ;;
    arch)   sudo pacman -Sy --noconfirm "$@" ;;
    alpine) sudo apk add "$@" ;;
    void)   sudo xbps-install -Sy "$@" ;;
    opensuse) sudo zypper install -y "$@" ;;
  esac
}

ARCH=$(uname -m)
DISTRO=$(detect_distro)
echo "[*] Detected distro: $DISTRO  |  Arch: $ARCH"

if [ "$ARCH" = "x86_64" ]; then
  EXTRA=""
else
  echo "[*] Setting up x86_64 emulation for aapt2..."
  case "$DISTRO" in
    alpine) EXTRA="box64" ;;
    debian) EXTRA="qemu-user-static" ;;
    fedora|rhel) EXTRA="qemu-user-static" ;;
    arch)   EXTRA="qemu-user-static" ;;
    void)   EXTRA="box64" ;;
    opensuse) EXTRA="qemu-user-static" ;;
    *)      EXTRA="" ;;
  esac
fi

case "$DISTRO" in
  debian)   PKG_JAVA="openjdk-17-jdk"     PKG_GLIBC=""             PKG_OTHER="curl unzip $EXTRA" ;;
  fedora|rhel) PKG_JAVA="java-17-openjdk" PKG_GLIBC=""             PKG_OTHER="curl unzip $EXTRA" ;;
  arch)     PKG_JAVA="jdk17-openjdk"      PKG_GLIBC=""             PKG_OTHER="curl unzip $EXTRA" ;;
  alpine)   PKG_JAVA="openjdk17"          PKG_GLIBC="gcompat libc6-compat" PKG_OTHER="curl unzip $EXTRA" ;;
  void)     PKG_JAVA="openjdk17-jdk"      PKG_GLIBC=""             PKG_OTHER="curl unzip $EXTRA" ;;
  opensuse) PKG_JAVA="java-17-openjdk"    PKG_GLIBC=""             PKG_OTHER="curl unzip $EXTRA" ;;
  *)
    echo "[-] Unsupported distro. Install java-17, curl, unzip manually." >&2
    exit 1
    ;;
esac

MISSING=""
command -v java  &>/dev/null || MISSING+=" $PKG_JAVA"
command -v curl  &>/dev/null || MISSING+=" curl"
command -v unzip &>/dev/null || MISSING+=" unzip"
command -v zip   &>/dev/null || MISSING+=" zip"
if [ "$DISTRO" = "alpine" ]; then
  command -v gcompat &>/dev/null || MISSING+=" $PKG_GLIBC"
fi

if [ -n "$MISSING" ]; then
  echo "[*] Installing missing packages:$MISSING"
  # shellcheck disable=SC2086
  distro_install "$DISTRO" $MISSING
fi

echo "[+] Java: $(java -version 2>&1 | head -1)"

# --- Alpine: ensure glibc linker symlink ---
if [ "$DISTRO" = "alpine" ] && [ ! -e /lib64/ld-linux-x86-64.so.2 ]; then
  echo "[*] Creating /lib64/ld-linux-x86-64.so.2 symlink..."
  sudo ln -sf /lib/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2
fi

# --- On non-x86_64: register binfmt for box64 so x86_64 binaries run transparently ---
if [ "$ARCH" != "x86_64" ] && command -v box64 &>/dev/null; then
  if [ ! -f /proc/sys/fs/binfmt_misc/register ]; then
    echo "[*] binfmt_misc not available — box64 will be used explicitly"
  elif [ ! -f /proc/sys/fs/binfmt_misc/box64 ] && [ ! -f /proc/sys/fs/binfmt_misc/qemu-x86_64 ]; then
    echo "[*] Registering box64 binfmt handler..."
    echo ':x86_64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00:\xff\xff\xff\xff\xff\xfe\xfe\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff\xff\xff:/usr/bin/box64:OC' | sudo tee /proc/sys/fs/binfmt_misc/register > /dev/null 2>&1 || true
  fi
fi

# --- Install Android SDK ---
if [ -d "$SDK_DIR/tools" ]; then
  echo "[*] cmdline-tools already installed at $SDK_DIR/tools"
else
  echo "[*] Downloading Android SDK command-line tools..."
  mkdir -p "$SDK_DIR"
  LATEST=$(curl -fsS https://developer.android.com/studio \
    | grep -oE 'commandlinetools-linux-[0-9]+_latest\.zip' \
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

# --- Also download apktool.jar as fallback ---
APKTOOL_JAR="$ANDROID_HOME/apktool.jar"
APKTOOL_WRAPPER="$ANDROID_HOME/apktool"
if [ ! -f "$APKTOOL_JAR" ]; then
  echo "[*] Downloading apktool.jar (fallback)..."
  curl -fSL "https://github.com/iBotPeaches/Apktool/releases/download/v2.11.1/apktool_2.11.1.jar" -o "$APKTOOL_JAR"
fi
if [ ! -f "$APKTOOL_WRAPPER" ]; then
  cat > "$APKTOOL_WRAPPER" << 'WRAP'
#!/usr/bin/env sh
exec java -jar "$(dirname "$0")/apktool.jar" "$@"
WRAP
  chmod +x "$APKTOOL_WRAPPER"
fi
export PATH="$ANDROID_HOME:$PATH"

echo "[+] Setup complete."
echo "    ANDROID_HOME=$ANDROID_HOME"
echo "    export ANDROID_HOME=\"$ANDROID_HOME\""
echo "    export PATH=\"\$ANDROID_HOME:\$PATH\""
