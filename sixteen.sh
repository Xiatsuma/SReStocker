#!/bin/bash
set -euo pipefail
if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <STOCK_DEVICE> <USE_UI_8_TETHERING_APEX> <OUTPUT_FILESYSTEM>"
    exit 1
fi
export STOCK_DEVICE="$1"
export USE_UI_8_TETHERING_APEX="$2"
export OUTPUT_FILESYSTEM="$3"
export TARGET_DEVICE="$STOCK_DEVICE"
if [[ "$OUTPUT_FILESYSTEM" != "erofs" && "$OUTPUT_FILESYSTEM" != "ext4" ]]; then
    echo "OUTPUT_FILESYSTEM must be erofs or ext4"
    exit 1
fi
export VERSION="1"
export OUT_DIR="$(pwd)/OUT"
export WORK_DIR="$(pwd)/WORK"
export FIRM_DIR="$(pwd)/FIRMWARE"
export DEVICES_DIR="$(pwd)/QuantumROM/Devices"
export APKTOOL="$(pwd)/bin/apktool/apktool.jar"
export VNDKS_COLLECTION="$(pwd)/QuantumROM/vndks"
export BUILD_PARTITIONS="product,system_ext,system"
source "$(pwd)/scripts/debloat.sh"
source "$(pwd)/scripts/QuantumRom.sh"
EXTRACT_FIRMWARE "$FIRM_DIR/$TARGET_DEVICE"
EXTRACT_FIRMWARE_IMG "$FIRM_DIR/$TARGET_DEVICE"
APPLY_STOCK_CONFIG "$FIRM_DIR/$TARGET_DEVICE"
DEBLOAT "$FIRM_DIR/$TARGET_DEVICE"
FIX_SELINUX "$FIRM_DIR/$TARGET_DEVICE"
APPLY_CUSTOM_FEATURES "$FIRM_DIR/$TARGET_DEVICE"
INSTALL_FRAMEWORK "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/framework-res.apk"
BUILD_IMG "$FIRM_DIR/$TARGET_DEVICE" "$OUTPUT_FILESYSTEM" "$OUT_DIR"
