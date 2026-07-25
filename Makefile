ANDROID_HOME ?= $(HOME)/Android/Sdk
BUILD_NUM ?= 1

export ANDROID_HOME

.PHONY: all setup overlays magisk-module clean

all: overlays

setup:
	@echo "[*] Installing dependencies..."
	@bash setup.sh

overlays:
	@echo "[*] Building overlays..."
	@bash build-overlays.sh

magisk-module: overlays
	@echo "[*] Building Magisk module..."
	@bash build-magisk-module.sh $(BUILD_NUM)

clean:
	rm -rf out/
	@echo "[*] Cleaned."
