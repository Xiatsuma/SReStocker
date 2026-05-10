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

    # Core Performance & UI Responsiveness
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "dalvik.vm.systemuicompilerfilter" "speed"
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "ro.surface_flinger.use_hw_overlays" "true"
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "debug.composition.type" "gpu"
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "sys.use_fifo_ui" "1"
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "ro.surface_flinger.max_frame_buffer_acquired_buffers" "3"
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "debug.sf.latch_unsignaled" "1"

    # Graphics & Rendering Stability
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "debug.egl.hw" "1"
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "debug.sf.disable_backpressure" "1"
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "debug.hwui.renderer" "skiavk"

    # Memory Management
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "dalvik.vm.heapgrowthlimit" "256m"
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "dalvik.vm.heapsize" "512m"
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "dalvik.vm.heaptargetutilization" "0.75"
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "ro.HOME_APP_ADJ" "1"
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "persist.sys.purgeable_assets" "1"

    # System Stability & Logging
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "ro.config.nocheckin" "1"
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "profiler.force_disable_err_rpt" "1"
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "profiler.force_disable_ulog" "1"

    # Networking Stability
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "net.tcp.congestion_control" "bbr"
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "net.tcp.default_init_rwnd" "60"
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "net.tcp.buffersize.default" "524288,1048576,2097152,524288,1048576,2097152"

    # Cosmetic Build Properties
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "ro.build.official.release" "false"
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "ro.build.official.developer" "true"

    # Existing Defaults
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "ro.product.locale" "en-US"
    CUSTOM_BUILD_PROP "$EXTRACTED_FIRM_DIR" "product" "ro.product.locale" "en-US"

    echo "- Custom build props done."
}
