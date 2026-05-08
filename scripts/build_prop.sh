#!/bin/bash

: "${YELLOW:=\e[33m}"
: "${NC:=\e[0m}"

CUSTOM_BUILD_PROP() {
    if [ "$#" -ne 4 ]; then
        echo "Usage: CUSTOM_BUILD_PROP <EXTRACTED_FIRM_DIR> <PARTITION> <KEY> <VALUE>"
        return 1
    fi
    local EXTRACTED_FIRM_DIR="$1"
    local PARTITION="$2"
    local KEY="$3"
    local VALUE="$4"
    echo "- Setting [$PARTITION] $KEY=$VALUE"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "$PARTITION" "$KEY" "$VALUE"
}

APPLY_CUSTOM_BUILD_PROPS() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: APPLY_CUSTOM_BUILD_PROPS <EXTRACTED_FIRM_DIR>"
        return 1
    fi
    local EXTRACTED_FIRM_DIR="$1"
    echo -e ""
    echo -e "${YELLOW}Applying Custom Build Props.${NC}"

    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "ro.product.locale"                    "en-US"
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "fw.max_users"                         "5"
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "fw.show_multiuserui"                  "1"
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "wifi.interface"                       "wlan0"
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "wlan.wfd.hdcp"                        "disabled"
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "debug.hwui.renderer"                  "skiavk"
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "ro.telephony.sim_slots.count"         "2"
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "ro.surface_flinger.protected_contents" "true"
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "ro.config.dmverity"                   "false"
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "ro.config.iccc_version"               "iccc_disabled"

    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "product" "ro.product.locale"                   "en-US"
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "product" "ro.config.dmverity"                  "false"
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "product" "ro.config.iccc_version"              "iccc_disabled"

    echo "- Custom build props done."
}
