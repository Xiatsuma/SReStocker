#!/bin/bash

set -euo pipefail

if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <STOCK_DEVICE> <TARGET_DEVICE> <OUTPUT_FILESYSTEM>"
    exit 1
fi

# Device info
export STOCK_DEVICE="$1"
export TARGET_DEVICE="$2"
export OUTPUT_FILESYSTEM="$3"

VERSION="1"

# Directories
export OUT_DIR="$(pwd)/OUT"
export WORK_DIR="$(pwd)/WORK"
export FIRM_DIR="$(pwd)/FIRMWARE"
export DEVICES_DIR="$(pwd)/QuantumROM/Devices"
export APKTOOL="$(pwd)/bin/apktool/apktool.jar"
export VNDKS_COLLECTION="$(pwd)/QuantumROM/vndks"

export BUILD_PARTITIONS="product,system_ext,system"

# Source all scripts
source "$(pwd)/scripts/debloat.sh"
source "$(pwd)/scripts/QuantumRom.sh"
source "$(pwd)/scripts/selinux_engine.sh"
source "$(pwd)/scripts/mods.sh"
source "$(pwd)/scripts/floating_features.sh"
source "$(pwd)/scripts/build_prop.sh"

# --- EXECUTION START ---

echo "Starting SReStocker Process..."
echo "Stock Device Config: $STOCK_DEVICE"
echo "Target Firmware Device: $TARGET_DEVICE"

EXTRACT_FIRMWARE "$FIRM_DIR/$TARGET_DEVICE"
EXTRACT_FIRMWARE_IMG "$FIRM_DIR/$TARGET_DEVICE"

# 1. Apply Stock Config (Sets up variables like $STOCK_ROM_FLOATING_FEATURE)
APPLY_STOCK_CONFIG "$FIRM_DIR/$TARGET_DEVICE"

# 2. Apply Stock Floating Features (CRITICAL: Must be after APPLY_STOCK_CONFIG)
APPLY_STOCK_ROM_FLOATING_FEATURE

# 3. Standard Modifications
DEBLOAT "$FIRM_DIR/$TARGET_DEVICE"
FIX_SELINUX "$FIRM_DIR/$TARGET_DEVICE"
APPLY_CUSTOM_FEATURES "$FIRM_DIR/$TARGET_DEVICE"

# 4. Advanced Mods & Custom Features
APPLY_MODS "$FIRM_DIR/$TARGET_DEVICE"
APPLY_CUSTOM_FLOATING_FEATURES
APPLY_CUSTOM_BUILD_PROPS "$FIRM_DIR/$TARGET_DEVICE"

# 5. Framework JAR Recompilation
INSTALL_FRAMEWORK "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/framework-res.apk"

DECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/ssrm.jar" "$WORK_DIR"
DECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/services.jar" "$WORK_DIR"
DECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/samsungkeystoreutils.jar" "$WORK_DIR"

RECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$WORK_DIR/ssrm" "$WORK_DIR"
RECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$WORK_DIR/services" "$WORK_DIR"
RECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$WORK_DIR/samsungkeystoreutils" "$WORK_DIR"
mv -f "$WORK_DIR"/*.jar "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/"

# 6. Update Build Props
D_ID="$(grep -m1 '^ro.build.PDA=' "$FIRM_DIR/$TARGET_DEVICE/system/system/build.prop" | cut -d= -f2 | tr -d '\r')"

NEW_ID="${D_ID}_SReStocker"

BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.build.display.id" "$NEW_ID"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.build.display.id" "$NEW_ID"

# 7. Build Final Image
BUILD_IMG "$FIRM_DIR/$TARGET_DEVICE" "$OUTPUT_FILESYSTEM" "$OUT_DIR"

echo "Process Complete! Output images are in $OUT_DIR"
