#!/bin/bash

: "${YELLOW:=\e[33m}"
: "${NC:=\e[0m}"

APPLY_MODS() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: APPLY_MODS <EXTRACTED_FIRM_DIR>"
        return 1
    fi
    local EXTRACTED_FIRM_DIR="$1"
    echo -e "${YELLOW}Applying Mods.${NC}"

    local MODS_SRC="$(pwd)/SReStocker/Mods/Apps"
    [ -d "$MODS_SRC" ] || { echo "- No Mods/Apps folder found, skipping."; return 0; }

    local SKIP_MODS=("JDM_Special" "PhotoEditor_AIFull")

    local APP_ROOTS=(
        "$EXTRACTED_FIRM_DIR/system/system/app"
        "$EXTRACTED_FIRM_DIR/system/system/priv-app"
        "$EXTRACTED_FIRM_DIR/product/app"
        "$EXTRACTED_FIRM_DIR/product/priv-app"
        "$EXTRACTED_FIRM_DIR/system_ext/app"
        "$EXTRACTED_FIRM_DIR/system_ext/priv-app"
    )

    for mod in "$MODS_SRC"/*; do
        [ -d "$mod" ] || continue
        local mod_name="$(basename "$mod")"

        local skip=0
        for s in "${SKIP_MODS[@]}"; do
            [ "$mod_name" = "$s" ] && skip=1 && break
        done
        [ "$skip" -eq 1 ] && continue

        local installed=0
        for root in "${APP_ROOTS[@]}"; do
            if [ -d "$root/$mod_name" ]; then
                echo "- Skipping mod (already exists): $mod_name"
                installed=1
                break
            fi
        done
        [ "$installed" -eq 1 ] && continue

        echo "- Applying mod: $mod_name"
        cp -rfa "$mod/." "$EXTRACTED_FIRM_DIR/"
    done

    if [ -d "$MODS_SRC/PhotoEditor_AIFull" ]; then
        echo "- Applying mod: PhotoEditor_AIFull (special)"
        rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/ailasso"
        rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/ailassomatting"
        rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/inpainting"
        rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/objectremoval"
        rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/reflectionremoval"
        rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/shadowremoval"
        rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/style_transfer"
        rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app"/PhotoEditor_*
        cp -rfa "$MODS_SRC/PhotoEditor_AIFull/." "$EXTRACTED_FIRM_DIR/"
        unzip -o "$EXTRACTED_FIRM_DIR/system/system/priv-app/PhotoEditor_AIFull.zip" \
            -d "$EXTRACTED_FIRM_DIR/system/system/priv-app/"
        rm -f "$EXTRACTED_FIRM_DIR/system/system/priv-app/PhotoEditor_AIFull.zip"
    fi

    if [ "${STOCK_DEVICE_TYPE:-}" = "jdm" ]; then
        echo "- Applying mod: JDM_Special SamSungCamera"
        rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/SamSungCamera"
        if [ -d "$MODS_SRC/JDM_Special/SamSungCamera" ]; then
            cp -rfa "$MODS_SRC/JDM_Special/SamSungCamera/." "$EXTRACTED_FIRM_DIR/"
        fi
    fi

    echo "- All mods applied."
}
