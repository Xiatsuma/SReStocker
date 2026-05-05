#!/bin/bash

###################################################################################################

RED="\e[31m"
YELLOW="\e[33m"
NC="\e[0m"

REAL_USER=${SUDO_USER:-$USER}

# Binary
chmod +x $(pwd)/bin/lp/lpunpack
chmod +x $(pwd)/bin/ext4/make_ext4fs
chmod +x $(pwd)/bin/erofs-utils/extract.erofs
chmod +x $(pwd)/bin/erofs-utils/mkfs.erofs

export TARGET_ROM_FLOATING_FEATURE="$FIRM_DIR/$TARGET_DEVICE/system/system/etc/floating_feature.xml"

CHECK_FILE() {
    if [ ! -f "$1" ]; then
        echo -e "[!] File not found: $1"
        echo -e "- Skipping..."
        return 1
    fi
    return 0
}

REMOVE_LINE() {
    if [ "$#" -ne 2 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <TARGET_LINE> <TARGET_FILE>"
        return 1
    fi
    local LINE="$1"
    local FILE="$2"
    echo -e "- Deleting $LINE from $FILE"
    grep -vxF "$LINE" "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"
}

GET_PROP() {
    if [ "$#" -ne 3 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR> <PARTITION> <PROP>"
        return 1
    fi
    local EXTRACTED_FIRM_DIR="$1"
    local PARTITION="$2"
    local PROP="$3"
    case "$PARTITION" in
        system)      FILE="$EXTRACTED_FIRM_DIR/system/system/build.prop" ;;
        vendor)      FILE="$EXTRACTED_FIRM_DIR/vendor/build.prop" ;;
        product)     FILE="$EXTRACTED_FIRM_DIR/product/etc/build.prop" ;;
        system_ext)  FILE="$EXTRACTED_FIRM_DIR/system_ext/etc/build.prop" ;;
        odm)         FILE="$EXTRACTED_FIRM_DIR/odm/etc/build.prop" ;;
        *)
            echo -e "Unknown partition: $PARTITION"
            return 1
            ;;
    esac
    if [ ! -f "$FILE" ]; then
        echo -e "$FILE not found."
        return 1
    fi
    local VALUE
    VALUE=$(grep -m1 "^${PROP}=" "$FILE" | cut -d'=' -f2-)
    if [ -z "$VALUE" ]; then
        return 1
    fi
    echo -e "$VALUE"
}

GET_FF_VALUE() {
    local KEY="$1"
    local FILE="$2"
    awk -F'[<>]' -v key="$KEY" '
        $2 == key { print $3; exit }
    ' "$FILE"
}

DOWNLOAD_FIRMWARE() {
    if [ "$#" -lt 2 ]; then
        echo "Usage: DOWNLOAD_FIRMWARE <MODEL> <DOWNLOAD_DIRECTORY>"
        return 1
    fi

    local MODEL="$1"
    local DOWN_DIR="${2}/${MODEL}"

    rm -rf "$DOWN_DIR"
    mkdir -p "$DOWN_DIR"

    [ -n "${SAMFW_URL:-}" ] || { echo "SAMFW_URL not set"; return 1; }

    echo "- Downloading firmware for $MODEL..."
    local LOGF="$DOWN_DIR/wget.log"
    if ! wget --no-check-certificate --progress=bar:force -O "$DOWN_DIR/firmware.zip" "$SAMFW_URL" 2>&1 | tee "$LOGF"; then
        echo "[ERROR] Download failed."
        rm -f "$LOGF"
        return 1
    fi
    rm -f "$LOGF"

    [ -f "$DOWN_DIR/firmware.zip" ] || return 1
    echo -e "${YELLOW}Firmware downloaded:${NC} $DOWN_DIR/firmware.zip"
}

EXTRACT_FIRMWARE() {
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <FIRMWARE_DIRECTORY>"
        return 1
    fi
    local FIRM_DIR="$1"
    echo -e "${YELLOW}Extracting downloaded firmware.${NC}"

    for file in "$FIRM_DIR"/*.zip; do
        if [ -f "$file" ]; then
            echo -e "- Extracting zip: $(basename "$file")"
            7z x -y -o"$FIRM_DIR" "$file"
            rm -f "$file"
        fi
    done

    rm -rf "$FIRM_DIR"/BL_*.tar.md5
    rm -f "$FIRM_DIR"/CP_*.tar.md5
    rm -f "$FIRM_DIR"/CSC_*.tar.md5

    for file in "$FIRM_DIR"/*.xz; do
        if [ -f "$file" ]; then
            echo -e "- Extracting xz: $(basename "$file")"
            7z x -y -o"$FIRM_DIR" "$file"
            rm -f "$file"
        fi
    done

    for file in "$FIRM_DIR"/*.md5; do
        if [ -f "$file" ]; then
            mv -- "$file" "${file%.md5}"
        fi
    done

    for file in "$FIRM_DIR"/*.tar; do
        if [ -f "$file" ]; then
            echo -e "- Extracting tar: $(basename "$file")"
            tar -xvf "$file" -C "$FIRM_DIR"
            rm -f "$file"
        fi
    done

    rm -rf $FIRM_DIR/{cache.img.lz4,dtbo.img.lz4,efuse.img.lz4,gz-verified.img.lz4,lk-verified.img.lz4,md1img.img.lz4,md_udc.img.lz4,misc.bin.lz4,omr.img.lz4,param.bin.lz4,preloader.img.lz4,recovery.img.lz4,scp-verified.img.lz4,spmfw-verified.img.lz4,sspm-verified.img.lz4,tee-verified.img.lz4,tzar.img.lz4,up_param.bin.lz4,userdata.img.lz4,vbmeta.img.lz4,vbmeta_system.img.lz4,audio_dsp-verified.img.lz4,cam_vpu1-verified.img.lz4,cam_vpu2-verified.img.lz4,cam_vpu3-verified.img.lz4,dpm-verified.img.lz4,init_boot.img.lz4,mcupm-verified.img.lz4,pi_img-verified.img.lz4,uh.bin.lz4,vendor_boot.img.lz4}
    for file in "$FIRM_DIR"/*.lz4; do
        if [ -f "$file" ]; then
            echo -e "- Extracting lz4: $(basename "$file")"
            lz4 -d "$file" "${file%.lz4}"
            rm -f "$file"
        fi
    done

    rm -rf \
        "$FIRM_DIR"/*.txt \
        "$FIRM_DIR"/*.pit \
        "$FIRM_DIR"/*.bin \
        "$FIRM_DIR"/meta-data

    if [ -f "$FIRM_DIR/super.img" ]; then
        echo -e "- Extracting super.img"
        simg2img "$FIRM_DIR/super.img" "$FIRM_DIR/super_raw.img"
        rm -f "$FIRM_DIR/super.img"
        "$(pwd)/bin/lp/lpunpack" "$FIRM_DIR/super_raw.img" "$FIRM_DIR"
        rm -f "$FIRM_DIR/super_raw.img"
        echo -e "- Extraction complete"
    fi
}

PREPARE_PARTITIONS() {
    if [ -z "$STOCK_DEVICE" ] || [ "$STOCK_DEVICE" = "None" ]; then
        export BUILD_PARTITIONS="odm,product,system_ext,system,vendor,odm_a,product_a,system_ext_a,system_a,vendor_a"
    fi
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi
    local EXTRACTED_FIRM_DIR="$1"
    [[ -z "$EXTRACTED_FIRM_DIR" || ! -d "$EXTRACTED_FIRM_DIR" ]] && {
        echo -e "Invalid directory: $EXTRACTED_FIRM_DIR"
        return 1
    }
    IFS=',' read -r -a KEEP <<< "$BUILD_PARTITIONS"
    for i in "${!KEEP[@]}"; do
        KEEP[$i]=$(echo -e "${KEEP[$i]}" | xargs)
    done
    echo -e "${YELLOW}Preparing partitions.${NC} $STOCK_DEVICE"
    find "$EXTRACTED_FIRM_DIR" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
    shopt -s nullglob dotglob
    for item in "$EXTRACTED_FIRM_DIR"/*; do
        base=$(basename "$item")
        [[ "$base" == *.img ]] && base="${base%.img}"
        keep_this=0
        for k in "${KEEP[@]}"; do
            [[ "$k" == "$base" ]] && keep_this=1 && break
        done
        if [[ $keep_this -eq 0 ]]; then
            rm -rf -- "$item"
        fi
    done
    shopt -u nullglob dotglob
}

EXTRACT_FIRMWARE_IMG() {
    echo -e ""
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <FIRMWARE_DIRECTORY>"
        return 1
    fi
    local FIRM_DIR="$1"
    PREPARE_PARTITIONS "$FIRM_DIR"
    echo -e "${YELLOW}Extracting images from:${NC} $FIRM_DIR"
    for imgfile in "$FIRM_DIR"/*.img; do
        [ -e "$imgfile" ] || continue
        if [[ "$(basename "$imgfile")" == "boot.img" ]]; then
            continue
        fi
        local partition fstype IMG_SIZE
        partition="$(basename "${imgfile%.img}")"
        fstype=$(blkid -o value -s TYPE "$imgfile")
        [ -z "$fstype" ] && fstype=$(file -b "$imgfile")
        case "$fstype" in
            ext4)
                IMG_SIZE=$(stat -c%s -- "$imgfile")
                echo -e "- $partition.img Detected ext4. Size: $IMG_SIZE bytes. Extracting..."
                rm -rf "$FIRM_DIR/$partition"
                python3 "$(pwd)/bin/py_scripts/imgextractor.py" "$imgfile" "$FIRM_DIR"
                ;;
            erofs)
                IMG_SIZE=$(stat -c%s -- "$imgfile")
                echo -e "- $partition.img Detected erofs. Size: $IMG_SIZE bytes. Extracting..."
                rm -rf "$FIRM_DIR/$partition"
                "$(pwd)/bin/erofs-utils/extract.erofs" -i "$imgfile" -x -f -o "$FIRM_DIR"
                ;;
            f2fs)
                IMG_SIZE=$(stat -c%s -- "$imgfile")
                echo -e "- $partition.img Detected f2fs. Size: $IMG_SIZE bytes. Converting to ext4"
                bash "$(pwd)/scripts/convert_to_ext4.sh" "$imgfile"
                rm -rf "$FIRM_DIR/$partition"
                python3 "$(pwd)/bin/py_scripts/imgextractor.py" "$imgfile" "$FIRM_DIR"
                ;;
            *)
                echo -e "- $partition.img unsupported filesystem type ($fstype), skipping"
                continue
                ;;
        esac
    done
    rm -rf "$FIRM_DIR"/*.img
    if ! ls "$FIRM_DIR"/system* >/dev/null 2>&1; then
        echo -e "❌ Firmware may be corrupt or unsupported."
        exit 1
    fi
    chown -R "$REAL_USER:$REAL_USER" "$FIRM_DIR"
    chmod -R u+rwX "$FIRM_DIR"
}

INSTALL_FRAMEWORK() {
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <framework-res.apk>"
        return 1
    fi
    echo -e ""
    local framework_apk="$1"
    echo -e "${YELLOW}Installing $framework_apk${NC}"
    java -jar "$APKTOOL" install-framework "$framework_apk"
}

DECOMPILE() {
    echo -e ""
    if [ "$#" -ne 4 ]; then
        echo -e "Usage: DECOMPILE <APKTOOL_JAR_DIR> <FRAMEWORK_DIR> <FILE> <DECOMPILE_DIR>"
        return 1
    fi
    local APKTOOL="$1"
    local FRAMEWORK_DIR="$2"
    local FILE="$3"
    local DECOMPILE_DIR="$4"
    local BASENAME="$(basename "${FILE%.*}")"
    local OUT="$DECOMPILE_DIR/$BASENAME"
    echo -e "${YELLOW}Decompiling:${NC} $FILE"
    rm -rf "$OUT"
    java -jar "$APKTOOL" d --force --frame-path "$FRAMEWORK_DIR" --match-original "$FILE" -o "$OUT"
}

RECOMPILE() {
    echo -e ""
    if [ "$#" -ne 4 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <APKTOOL_JAR_DIR> <FRAMEWORK_DIR> <DECOMPILED_DIR> <RECOMPILE_DIR>"
        return 1
    fi
    local APKTOOL="$1"
    local FRAMEWORK_DIR="$2"
    local DECOMPILED_DIR="$3"
    local RECOMPILE_DIR="$4"
    local org_file_name
    org_file_name=$(awk '/^apkFileName:/ {print $2}' "$DECOMPILED_DIR/apktool.yml")
    local name="${org_file_name%.*}"
    local ext="${org_file_name##*.}"
    local built_file="$WORK_DIR/${name}.$ext"
    echo -e "${YELLOW}Recompiling:${NC} $DECOMPILED_DIR"
    java -jar "$APKTOOL" b "$DECOMPILED_DIR" --copy-original --frame-path "$FRAMEWORK_DIR" -o "$built_file"
    rm -rf "$DECOMPILED_DIR"
}

ADD_SYSTEM_EXT_IN_SYSTEM_ROOT() {
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi
    local EXTRACTED_FIRM_DIR="$1"
    echo -e "- Copying system_ext content into system root"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system_ext"
    mv "$EXTRACTED_FIRM_DIR/system_ext" "$EXTRACTED_FIRM_DIR/system"
    echo -e "- Cleaning and merging system_ext file contexts and configs"
    SYSTEM_EXT_CONFIG_FILE="$EXTRACTED_FIRM_DIR/config/system_ext_fs_config"
    SYSTEM_EXT_CONTEXTS_FILE="$EXTRACTED_FIRM_DIR/config/system_ext_file_contexts"
    SYSTEM_CONFIG_FILE="$EXTRACTED_FIRM_DIR/config/system_fs_config"
    SYSTEM_CONTEXTS_FILE="$EXTRACTED_FIRM_DIR/config/system_file_contexts"
    SYSTEM_EXT_TEMP_CONFIG="${SYSTEM_EXT_CONFIG_FILE}.tmp"
    SYSTEM_EXT_TEMP_CONTEXTS="${SYSTEM_EXT_CONTEXTS_FILE}.tmp"
    grep -v '^/ u:object_r:system_file:s0$' "$SYSTEM_EXT_CONTEXTS_FILE" \
    | grep -v '^/system_ext u:object_r:system_file:s0$' \
    | grep -v '^/system_ext(.*)? u:object_r:system_file:s0$' \
    | grep -v '^/system_ext/ u:object_r:system_file:s0$' \
    > "$SYSTEM_EXT_TEMP_CONTEXTS" && mv "$SYSTEM_EXT_TEMP_CONTEXTS" "$SYSTEM_EXT_CONTEXTS_FILE"
    grep -v '^/ 0 0 0755$' "$SYSTEM_EXT_CONFIG_FILE" \
    | grep -v '^system_ext/ 0 0 0755$' \
    | grep -v '^system_ext/lost+found 0 0 0755$' \
    > "$SYSTEM_EXT_TEMP_CONFIG" && mv "$SYSTEM_EXT_TEMP_CONFIG" "$SYSTEM_EXT_CONFIG_FILE"
    awk '{print "system/" $0}' "$SYSTEM_EXT_CONFIG_FILE" \
    > "$SYSTEM_EXT_TEMP_CONFIG" && mv "$SYSTEM_EXT_TEMP_CONFIG" "$SYSTEM_EXT_CONFIG_FILE"
    awk '{print "/system" $0}' "$SYSTEM_EXT_CONTEXTS_FILE" \
    > "$SYSTEM_EXT_TEMP_CONTEXTS" && mv "$SYSTEM_EXT_TEMP_CONTEXTS" "$SYSTEM_EXT_CONTEXTS_FILE"
    cat "$SYSTEM_EXT_CONFIG_FILE" >> "$SYSTEM_CONFIG_FILE"
    cat "$SYSTEM_EXT_CONTEXTS_FILE" >> "$SYSTEM_CONTEXTS_FILE"
    rm -rf "$EXTRACTED_FIRM_DIR"/config/system_ext*
    export TARGET_ROM_SYSTEM_EXT_DIR="$EXTRACTED_FIRM_DIR/system/system_ext"
}

SEPARATE_SYSTEM_EXT() {
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi
    local EXTRACTED_FIRM_DIR="$1"
    echo "- Separating system_ext"
    mv "$EXTRACTED_FIRM_DIR/system/system/system_ext" "$EXTRACTED_FIRM_DIR/"
    ln -s /system_ext $EXTRACTED_FIRM_DIR/system/system/system_ext
    rm -rf "$EXTRACTED_FIRM_DIR/system/system_ext"
    mkdir "$EXTRACTED_FIRM_DIR/system/system_ext"
    SYSTEM_FS_CONFIG="$EXTRACTED_FIRM_DIR/config/system_fs_config"
    SYSTEM_FILE_CONTEXTS="$EXTRACTED_FIRM_DIR/config/system_file_contexts"
    SYSTEM_EXT_FS_CONFIG="$EXTRACTED_FIRM_DIR/config/system_ext_fs_config"
    SYSTEM_EXT_FILE_CONTEXTS="$EXTRACTED_FIRM_DIR/config/system_ext_file_contexts"
    if grep -q '^/system/system/system_ext' "$SYSTEM_FILE_CONTEXTS"; then
        grep '^/system/system/system_ext' "$SYSTEM_FILE_CONTEXTS" > "$SYSTEM_EXT_FILE_CONTEXTS"
        sed -i '\|^/system/system/system_ext|d' "$SYSTEM_FILE_CONTEXTS"
        awk '{sub(/^\/system\/system\/system_ext/, "/system_ext"); print}' "$SYSTEM_EXT_FILE_CONTEXTS" > "$SYSTEM_EXT_FILE_CONTEXTS.tmp" && \
        mv "$SYSTEM_EXT_FILE_CONTEXTS.tmp" "$SYSTEM_EXT_FILE_CONTEXTS"
        grep -qxF '/system/system_ext u:object_r:system_file:s0' "$SYSTEM_FILE_CONTEXTS" || echo '/system/system_ext u:object_r:system_file:s0' >> "$SYSTEM_FILE_CONTEXTS"
        grep -qxF '/system/system/system_ext u:object_r:system_file:s0' "$SYSTEM_EXT_FILE_CONTEXTS" || echo '/system/system/system_ext u:object_r:system_file:s0' >> "$SYSTEM_EXT_FILE_CONTEXTS"
        grep -qxF '/ u:object_r:system_file:s0' "$SYSTEM_EXT_FILE_CONTEXTS" || echo '/ u:object_r:system_file:s0' >> "$SYSTEM_EXT_FILE_CONTEXTS"
        sort -u "$SYSTEM_EXT_FILE_CONTEXTS" -o "$SYSTEM_EXT_FILE_CONTEXTS"
    fi
    if grep -q '^system/system/system_ext' "$SYSTEM_FS_CONFIG"; then
        grep '^system/system/system_ext' "$SYSTEM_FS_CONFIG" > "$SYSTEM_EXT_FS_CONFIG"
        sed -i '\|^system/system/system_ext|d' "$SYSTEM_FS_CONFIG"
        awk '{sub(/^system\/system\/system_ext/, "system_ext"); print}' "$SYSTEM_EXT_FS_CONFIG" > "$SYSTEM_EXT_FS_CONFIG.tmp" && \
        mv "$SYSTEM_EXT_FS_CONFIG.tmp" "$SYSTEM_EXT_FS_CONFIG"
        grep -qxF 'system/system_ext 0 0 0755' "$SYSTEM_FS_CONFIG" || echo 'system/system_ext 0 0 0755' >> "$SYSTEM_FS_CONFIG"
        grep -qxF 'system/system/system_ext 0 0 0644' "$SYSTEM_FS_CONFIG" || echo 'system/system/system_ext 0 0 0644' >> "$SYSTEM_FS_CONFIG"
        grep -qxF '/ 0 0 0755' "$SYSTEM_EXT_FS_CONFIG" || echo '/ 0 0 0755' >> "$SYSTEM_EXT_FS_CONFIG"
        grep -qxF 'system_ext/ 0 0 0755' "$SYSTEM_EXT_FS_CONFIG" || echo 'system_ext/ 0 0 0755' >> "$SYSTEM_EXT_FS_CONFIG"
        sort -u "$SYSTEM_EXT_FS_CONFIG" -o "$SYSTEM_EXT_FS_CONFIG"
    fi
    export TARGET_ROM_SYSTEM_EXT_DIR="$EXTRACTED_FIRM_DIR/system_ext"
}

ADJUST_SYSTEM_EXT() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi
    local EXTRACTED_FIRM_DIR="$1"
    if [ "${STOCK_HAS_SEPARATE_SYSTEM_EXT:-}" = "FALSE" ]; then
        echo "- STOCK_HAS_SEPARATE_SYSTEM_EXT: $STOCK_HAS_SEPARATE_SYSTEM_EXT"
        if [ -d "$EXTRACTED_FIRM_DIR/system/system/system_ext/apex" ]; then
            export TARGET_ROM_SYSTEM_EXT_DIR="$EXTRACTED_FIRM_DIR/system/system/system_ext"
        elif [ -d "$EXTRACTED_FIRM_DIR/system/system_ext/apex" ]; then
            export TARGET_ROM_SYSTEM_EXT_DIR="$EXTRACTED_FIRM_DIR/system/system_ext"
        elif [ -d "$EXTRACTED_FIRM_DIR/system_ext/apex" ]; then
            ADD_SYSTEM_EXT_IN_SYSTEM_ROOT "$EXTRACTED_FIRM_DIR"
        fi
    elif [ "${STOCK_HAS_SEPARATE_SYSTEM_EXT:-}" = "TRUE" ]; then
        echo "STOCK_HAS_SEPARATE_SYSTEM_EXT: $STOCK_HAS_SEPARATE_SYSTEM_EXT"
        if [ -d "$EXTRACTED_FIRM_DIR/system/system/system_ext/apex" ]; then
            SEPARATE_SYSTEM_EXT "$EXTRACTED_FIRM_DIR"
        fi
    fi
    echo "- TARGET_ROM_SYSTEM_EXT_DIR set to: ${TARGET_ROM_SYSTEM_EXT_DIR:-not set}"
}

UPDATE_FLOATING_FEATURE() {
    local key="$1"
    local value="$2"
    if [[ -z "$value" ]]; then
        echo -e "- Skipping $key — no value found."
        return
    fi
    if grep -q "<${key}>.*</${key}>" "$TARGET_ROM_FLOATING_FEATURE"; then
        local current_line
        current_line=$(grep "<${key}>.*</${key}>" "$TARGET_ROM_FLOATING_FEATURE")
        local current_value
        current_value=$(echo -e "$current_line" | sed -E "s/.*<${key}>(.*)<\/${key}>.*/\1/")
        if [[ "$current_value" == "$value" ]]; then
            return
        fi
        local indent
        indent=$(echo -e "$current_line" | sed -E "s/(<${key}>.*<\/${key}>).*//")
        local line="${indent}<${key}>${value}</${key}>"
        sed -i "s|${indent}<${key}>.*</${key}>|$line|" "$TARGET_ROM_FLOATING_FEATURE"
    else
        local line="    <$key>$value</$key>"
        sed -i "3i\\$line" "$TARGET_ROM_FLOATING_FEATURE"
    fi
}

APPLY_STOCK_CONFIG() {
    echo -e ""
    if [ -z "$STOCK_DEVICE" ] || [ "$STOCK_DEVICE" = "None" ]; then
        echo -e "No target device is set. Just modifying ROM without any device config."
        return 1
    fi
    echo -e "${YELLOW}Applying $STOCK_DEVICE device config.${NC}"
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi
    local EXTRACTED_FIRM_DIR="$1"
    if [ ! -f "$DEVICES_DIR/$STOCK_DEVICE/config" ]; then
        echo -e "- Config file for $STOCK_DEVICE not found in $DEVICES_DIR"
        return 1
    fi
    echo -e "- $STOCK_DEVICE config found."
    export STOCK_VNDK_VERSION="$(grep -m1 '^STOCK_VNDK_VERSION=' "$DEVICES_DIR/$STOCK_DEVICE/config" | cut -d= -f2 | tr -d '\r')"
    export STOCK_HAS_SEPARATE_SYSTEM_EXT="$(grep -m1 '^STOCK_HAS_SEPARATE_SYSTEM_EXT=' "$DEVICES_DIR/$STOCK_DEVICE/config" | cut -d= -f2 | tr -d '\r')"
    export STOCK_DVFS_FILENAME="$(grep -m1 '^STOCK_DVFS_FILENAME=' "$DEVICES_DIR/$STOCK_DEVICE/config" | cut -d= -f2 | tr -d '\r')"
    echo "- Stock device vndk version: $STOCK_VNDK_VERSION"
    export STOCK_ROM_FLOATING_FEATURE="$DEVICES_DIR/$STOCK_DEVICE/floating_feature.xml"
    export STOCK_SIOP_POLICY_FILENAME="$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_SYSTEM_CONFIG_SIOP_POLICY_FILENAME" {print $3}' "$STOCK_ROM_FLOATING_FEATURE" | tr -d '\r' | xargs)"
    export STOCK_DEVICE_TYPE="$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_COMMON_CONFIG_DEVICE_MANUFACTURING_TYPE" {print $3}' "$STOCK_ROM_FLOATING_FEATURE" | tr -d '\r' | xargs)"
    echo "- Stock device type: ${STOCK_DEVICE_TYPE:-unknown}"

    ADJUST_SYSTEM_EXT "$EXTRACTED_FIRM_DIR"

    if [ "${STOCK_DEVICE_TYPE:-}" != "jdm" ]; then
        rm -rf "$EXTRACTED_FIRM_DIR/system/system/cameradata/portrait_data"
    fi

    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/init"/rscmgr*.rc
    find "$EXTRACTED_FIRM_DIR/system/system/media" -maxdepth 1 -type f \( -iname "*.spi" -o -iname "*.qmg" -o -iname "*.txt" \) -delete
    rm -rf "$EXTRACTED_FIRM_DIR/product/overlay"/framework-res*auto_generated_rro_product.apk
    rm -rf "$EXTRACTED_FIRM_DIR/product/overlay"/SystemUI*auto_generated_rro_product.apk
    cp -a "$DEVICES_DIR/$STOCK_DEVICE/Stock/." "$EXTRACTED_FIRM_DIR/"
    if [ -d "$DEVICES_DIR/$STOCK_DEVICE/extra" ]; then
        cp -af "$DEVICES_DIR/$STOCK_DEVICE/extra/." "$(pwd)/OUT"
    fi
}

BUILD_PROP() {
    if [ "$#" -lt 3 ]; then
        echo -e "Usage: BUILD_PROP <EXTRACTED_FIRM_DIR> <PARTITION> <KEY> [VALUE]"
        return 1
    fi
    local EXTRACTED_FIRM_DIR="$1"
    local PARTITION="$2"
    local KEY="$3"
    local VALUE="${4-}"
    local FILE=""
    case "$PARTITION" in
        system)      FILE="$EXTRACTED_FIRM_DIR/system/system/build.prop" ;;
        vendor)      FILE="$EXTRACTED_FIRM_DIR/vendor/build.prop" ;;
        product)     FILE="$EXTRACTED_FIRM_DIR/product/etc/build.prop" ;;
        system_ext)  FILE="$EXTRACTED_FIRM_DIR/system_ext/etc/build.prop" ;;
        odm)         FILE="$EXTRACTED_FIRM_DIR/odm/etc/build.prop" ;;
        *)
            echo -e "Unknown partition: $PARTITION"
            return 1
            ;;
    esac
    if [ ! -f "$FILE" ]; then
        echo -e "build.prop not found: $FILE"
        return 1
    fi
    if grep -q "^${KEY}=" "$FILE"; then
        if [ -z "$VALUE" ]; then
            sed -i "s|^${KEY}=.*|${KEY}=|" "$FILE"
        else
            sed -i "s|^${KEY}=.*|${KEY}=${VALUE}|" "$FILE"
        fi
    else
        if [ -z "$VALUE" ]; then
            echo -e "${KEY}=" >> "$FILE"
        else
            echo -e "${KEY}=${VALUE}" >> "$FILE"
        fi
    fi
}

DISABLE_SECURITY() {
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi
    local EXTRACTED_FIRM_DIR="$1"
    echo -e "- Disabling security related things..."
    if [ -f "$EXTRACTED_FIRM_DIR/product/etc/build.prop" ]; then
        BUILD_PROP "$EXTRACTED_FIRM_DIR" "product" "ro.frp.pst" ""
    fi
    if [ -f "$EXTRACTED_FIRM_DIR/vendor/build.prop" ]; then
        BUILD_PROP "$EXTRACTED_FIRM_DIR" "vendor" "ro.frp.pst" ""
    fi
    if [ -f "$EXTRACTED_FIRM_DIR/vendor/recovery-from-boot.p" ]; then
        rm -rf "$EXTRACTED_FIRM_DIR/vendor/recovery-from-boot.p"
    fi
}

APPLY_CUSTOM_FEATURES() {
    echo -e ""
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi
    local EXTRACTED_FIRM_DIR="$1"
    echo -e "${YELLOW}Applying useful features.${NC}"
    DISABLE_SECURITY "$EXTRACTED_FIRM_DIR"

    # Fix Samsung AI Photo Editor Crash.
    if [ -f "$EXTRACTED_FIRM_DIR/system/system/cameradata/portrait_data/single_bokeh_feature.json" ]; then
        echo "- Fixing AI Photo Editor crash."
        sed -i '0,/"ModelType": "MODEL_TYPE_INSTANCE_CAPTURE"/s//"ModelType": "MODEL_TYPE_OBJ_INSTANCE_CAPTURE"/' \
            "$EXTRACTED_FIRM_DIR/system/system/cameradata/portrait_data/single_bokeh_feature.json"
    fi

    chown -R "$REAL_USER:$REAL_USER" "$EXTRACTED_FIRM_DIR"
    chmod -R u+rwX "$EXTRACTED_FIRM_DIR"
}

GEN_FS_CONFIG() {
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi
    local EXTRACTED_FIRM_DIR="$1"
    [ ! -d "$EXTRACTED_FIRM_DIR" ] && { echo -e "- $EXTRACTED_FIRM_DIR not found."; return 1; }
    [ ! -d "$EXTRACTED_FIRM_DIR/config" ] && { echo -e "[ERROR] config directory missing"; return 1; }
    for ROOT in "$EXTRACTED_FIRM_DIR"/*; do
        [ ! -d "$ROOT" ] && continue
        PARTITION="$(basename "$ROOT")"
        [ "$PARTITION" = "config" ] && continue
        local FS_CONFIG="$EXTRACTED_FIRM_DIR/config/${PARTITION}_fs_config"
        local TMP_EXISTING="$(mktemp)"
        touch "$FS_CONFIG"
        echo -e ""
        echo -e "${YELLOW}Generating fs_config for partition:${NC} $PARTITION"
        awk '{print $1}' "$FS_CONFIG" | sort -u > "$TMP_EXISTING"
        find "$ROOT" -mindepth 1 \( -type f -o -type d -o -type l \) | while IFS= read -r item; do
            REL_PATH="${item#$ROOT/}"
            PATH_ENTRY="$PARTITION/$REL_PATH"
            grep -qxF "$PATH_ENTRY" "$TMP_EXISTING" && continue
            if [ -d "$item" ]; then
                echo -e "- Adding: $PATH_ENTRY 0 0 0755"
                printf "%s 0 0 0755\n" "$PATH_ENTRY" >> "$FS_CONFIG"
            else
                if [[ "$REL_PATH" == */bin/* ]]; then
                    echo -e "- Adding: $PATH_ENTRY 0 2000 0755"
                    printf "%s 0 2000 0755\n" "$PATH_ENTRY" >> "$FS_CONFIG"
                else
                    echo -e "- Adding: $PATH_ENTRY 0 0 0644"
                    printf "%s 0 0 0644\n" "$PATH_ENTRY" >> "$FS_CONFIG"
                fi
            fi
        done
        rm -f "$TMP_EXISTING"
        echo -e "- $PARTITION fs_config generated"
    done
}

GEN_FILE_CONTEXTS() {
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi
    local EXTRACTED_FIRM_DIR="$1"
    [ ! -d "$EXTRACTED_FIRM_DIR" ] && { echo -e "- $EXTRACTED_FIRM_DIR not found."; return 1; }
    [ ! -d "$EXTRACTED_FIRM_DIR/config" ] && { echo -e "[ERROR] config directory missing"; return 1; }
    escape_path() {
        local path="$1"
        local result=""
        local c
        for ((i=0; i<${#path}; i++)); do
            c="${path:i:1}"
            case "$c" in
                '.'|'+'|'['|']'|'*'|'?'|'^'|'$'|'\\')
                    result+="\\$c" ;;
                *)
                    result+="$c" ;;
            esac
        done
        printf '%s' "$result"
    }
    for ROOT in "$EXTRACTED_FIRM_DIR"/*; do
        [ ! -d "$ROOT" ] && continue
        local PARTITION
        PARTITION="$(basename "$ROOT")"
        [ "$PARTITION" = "config" ] && continue
        local FILE_CONTEXTS="$EXTRACTED_FIRM_DIR/config/${PARTITION}_file_contexts"
        touch "$FILE_CONTEXTS"
        echo -e ""
        echo -e "${YELLOW}Generating file_contexts for partition:${NC} $PARTITION"
        declare -A EXISTING=()
        while IFS= read -r line || [[ -n "$line" ]]; do
            [ -z "$line" ] && continue
            local PATH_ONLY
            PATH_ONLY=$(echo -e "$line" | awk '{print $1}')
            EXISTING["$PATH_ONLY"]=1
        done < "$FILE_CONTEXTS"
        find "$ROOT" -mindepth 1 \( -type f -o -type d -o -type l \) | while IFS= read -r item; do
            local REL_PATH="${item#$ROOT}"
            local PATH_ENTRY="/$PARTITION$REL_PATH"
            local ESCAPED_PATH
            ESCAPED_PATH="/$(escape_path "${PATH_ENTRY#/}")"
            [[ -n "${EXISTING[$ESCAPED_PATH]-}" ]] && continue
            local CONTEXT="u:object_r:system_file:s0"
            local BASENAME
            BASENAME=$(basename "$item")
            if [[ "$BASENAME" == "linker" || "$BASENAME" == "linker64" ]]; then
                CONTEXT="u:object_r:system_linker_exec:s0"
            fi
            printf "%s %s\n" "$ESCAPED_PATH" "$CONTEXT" >> "$FILE_CONTEXTS"
            echo -e "- Added: $ESCAPED_PATH"
            EXISTING["$ESCAPED_PATH"]=1
        done
        echo -e "- $PARTITION file_contexts generated"
        unset EXISTING
    done
}

BUILD_IMG() {
    if [ "$#" -ne 3 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR> <FILE_SYSTEM> <OUT_DIR>"
        return 1
    fi
    local EXTRACTED_FIRM_DIR="$1"
    local FILE_SYSTEM="$2"
    local OUT_DIR="$3"
    GEN_FS_CONFIG "$EXTRACTED_FIRM_DIR"
    GEN_FILE_CONTEXTS "$EXTRACTED_FIRM_DIR"
    for PART in "$EXTRACTED_FIRM_DIR"/*; do
        [[ -d "$PART" ]] || continue
        PARTITION="$(basename "$PART")"
        [[ "$PARTITION" == "config" ]] && continue
        local SRC_DIR="$EXTRACTED_FIRM_DIR/$PARTITION"
        local OUT_IMG="$OUT_DIR/${PARTITION}.img"
        local FS_CONFIG="$EXTRACTED_FIRM_DIR/config/${PARTITION}_fs_config"
        local FILE_CONTEXTS="$EXTRACTED_FIRM_DIR/config/${PARTITION}_file_contexts"
        local SIZE=$(du -sb --apparent-size "$SRC_DIR" | awk '{printf "%.0f", $1 * 1.2}')
        MOUNT_POINT="/$PARTITION"
        echo -e ""
        [[ -f "$FS_CONFIG" ]] || { echo -e "Warning: $FS_CONFIG missing, skipping $PARTITION"; continue; }
        [[ -f "$FILE_CONTEXTS" ]] || { echo -e "Warning: $FILE_CONTEXTS missing, skipping $PARTITION"; continue; }
        sort -u "$FILE_CONTEXTS" -o "$FILE_CONTEXTS"
        sort -u "$FS_CONFIG" -o "$FS_CONFIG"
        if [[ "$FILE_SYSTEM" == "erofs" ]]; then
            echo -e "${YELLOW}Building EROFS image:${NC} $OUT_IMG"
            $(pwd)/bin/erofs-utils/mkfs.erofs --mount-point="$MOUNT_POINT" --fs-config-file="$FS_CONFIG" --file-contexts="$FILE_CONTEXTS" -z lz4hc -b 4096 -T 1199145600 "$OUT_IMG" "$SRC_DIR"
        elif [[ "$FILE_SYSTEM" == "ext4" ]]; then
            echo -e "${YELLOW}Building ext4 image:${NC} $OUT_IMG"
            $(pwd)/bin/ext4/make_ext4fs -l "$(awk "BEGIN {printf \"%.0f\", $SIZE * 1.1}")" -J -b 4096 -S "$FILE_CONTEXTS" -C "$FS_CONFIG" -a "$MOUNT_POINT" -L "$PARTITION" "$OUT_IMG" "$SRC_DIR"
            resize2fs -M "$OUT_IMG"
        else
            echo -e "Unknown filesystem: $FILE_SYSTEM, skipping $PARTITION"
            continue
        fi
    done
}
