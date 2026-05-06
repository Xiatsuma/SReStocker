#!/bin/bash
# ==============================================================================
# SReStocker - Mods Apply Script
# How to use:
#   - To DISABLE a mod: put # at the start of its line
#   - To ADD a mod: copy the format and add your line
#   - To EDIT a mod: change the path
# ==============================================================================

: "${YELLOW:=\e[33m}"
: "${NC:=\e[0m}"

APPLY_MODS() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: APPLY_MODS <EXTRACTED_FIRM_DIR>"
        return 1
    fi
    local EXTRACTED_FIRM_DIR="$1"
    echo -e "${YELLOW}Applying Mods.${NC}"

    # --------------------------------------------------------------------------
    # AiWallpaper
    # --------------------------------------------------------------------------
    if [ ! -d "$EXTRACTED_FIRM_DIR/product/priv-app/AiWallpaper" ]; then
        echo "- Applying mod: AiWallpaper"
        cp -rfa "$(pwd)/QuantumROM/Mods/Apps/AiWallpaper/." "$EXTRACTED_FIRM_DIR/"
    else
        echo "- Skipping mod (already exists): AiWallpaper"
    fi

    # --------------------------------------------------------------------------
    # ClockPackage
    # --------------------------------------------------------------------------
    if [ ! -d "$EXTRACTED_FIRM_DIR/system/system/app/ClockPackage" ]; then
        echo "- Applying mod: ClockPackage"
        cp -rfa "$(pwd)/QuantumROM/Mods/Apps/ClockPackage/." "$EXTRACTED_FIRM_DIR/"
    else
        echo "- Skipping mod (already exists): ClockPackage"
    fi

    # --------------------------------------------------------------------------
    # SecCalculator_R
    # --------------------------------------------------------------------------
    if [ ! -d "$EXTRACTED_FIRM_DIR/system/system/app/SecCalculator_R" ]; then
        echo "- Applying mod: SecCalculator_R"
        cp -rfa "$(pwd)/QuantumROM/Mods/Apps/SecCalculator_R/." "$EXTRACTED_FIRM_DIR/"
    else
        echo "- Skipping mod (already exists): SecCalculator_R"
    fi

    # --------------------------------------------------------------------------
    # PhotoEditor_AIFull
    # --------------------------------------------------------------------------
    if [ ! -d "$EXTRACTED_FIRM_DIR/system/system/priv-app/PhotoEditor_AIFull" ]; then
        echo "- Applying mod: PhotoEditor_AIFull"
        rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/ailasso"
        rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/ailassomatting"
        rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/inpainting"
        rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/objectremoval"
        rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/reflectionremoval"
        rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/shadowremoval"
        rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/style_transfer"
        rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app"/PhotoEditor_*
        cp -rfa "$(pwd)/QuantumROM/Mods/Apps/PhotoEditor_AIFull/." "$EXTRACTED_FIRM_DIR/"
        unzip -o "$EXTRACTED_FIRM_DIR/system/system/priv-app/PhotoEditor_AIFull.zip" \
            -d "$EXTRACTED_FIRM_DIR/system/system/priv-app/"
        rm -f "$EXTRACTED_FIRM_DIR/system/system/priv-app/PhotoEditor_AIFull.zip"
    else
        echo "- Skipping mod (already exists): PhotoEditor_AIFull"
    fi

    # --------------------------------------------------------------------------
    # JDM Special (only if device type is jdm)
    # --------------------------------------------------------------------------
    if [ "${STOCK_DEVICE_TYPE:-}" = "jdm" ]; then
        echo "- Applying mod: JDM_Special SamSungCamera"
        rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/SamSungCamera"
        cp -rfa "$(pwd)/QuantumROM/Mods/Apps/JDM_Special/SamSungCamera/." "$EXTRACTED_FIRM_DIR/"
    else
        echo "- Skipping mod (not jdm device): JDM_Special"
    fi

    echo "- All mods applied."
}
