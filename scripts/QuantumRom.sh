#!/bin/bash

###################################################################################################

YELLOW="\e[33m"
NC="\e[0m"

REAL_USER=${SUDO_USER:-$USER}

# Binary
chmod +x $(pwd)/bin/lp/lpunpack
chmod +x $(pwd)/bin/ext4/make_ext4fs
chmod +x $(pwd)/bin/erofs-utils/extract.erofs
chmod +x $(pwd)/bin/erofs-utils/mkfs.erofs

# Source debloat system
source "$(pwd)/scripts/debloat.sh"

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
        system)
            FILE="$EXTRACTED_FIRM_DIR/system/system/build.prop"
            ;;
        vendor)
            FILE="$EXTRACTED_FIRM_DIR/vendor/build.prop"
            ;;
        product)
            FILE="$EXTRACTED_FIRM_DIR/product/etc/build.prop"
            ;;
        system_ext)
            FILE="$EXTRACTED_FIRM_DIR/system_ext/etc/build.prop"
            ;;
        odm)
            FILE="$EXTRACTED_FIRM_DIR/odm/etc/build.prop"
            ;;
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

DOWNLOAD_FIRMWARE() {
    if [ "$#" -lt 4 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <MODEL> <CSC> <IMEI> <DOWNLOAD_DIRECTORY> [VERSION]"
        return 1
    fi

    local MODEL="$1"
    local CSC="$2"
    local IMEI="$3"
    local DOWN_DIR="${4}/$MODEL"
    local VERSION="${5:-}"

    rm -rf "$DOWN_DIR"
    mkdir -p "$DOWN_DIR"

    echo -e "======================================"
    echo -e "${YELLOW}  Samsung FW Downloader (SamFW)  ${NC}"
    echo -e "======================================"
    echo -e "MODEL: $MODEL | CSC: $CSC"

    # Download using SamFW direct link (passed via env var)
    echo -e "- Downloading firmware via SamFW..."
    
    if [ -z "$SAMFW_URL" ]; then
        echo -e "- SAMFW_URL not set!"
        return 1
    fi
    
    wget --no-check-certificate -O "$DOWN_DIR/firmware.zip" "$SAMFW_URL" 2>&1 | tail -3
    
    if [ $? -ne 0 ] || [ ! -f "$DOWN_DIR/firmware.zip" ]; then
        echo -e "- Download failed. Check URL."
        return 1
    fi

    # Show firmware info
    file_size=$(du -m "$DOWN_DIR/firmware.zip" | cut -f1)
    echo -e "- Firmware downloaded successfully! Size: ${file_size} MB"
    echo -e "- Saved to: $DOWN_DIR/firmware.zip"
}

EXTRACT_FIRMWARE() {
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <FIRMWARE_DIRECTORY>"
        return 1
    fi

    local FIRM_DIR="$1"

    echo -e "${YELLOW}Extracting downloaded firmware.${NC}"

    # ---- ZIP ----
    for file in "$FIRM_DIR"/*.zip; do
        if [ -f "$file" ]; then
            echo -e "- Extracting zip: $(basename "$file")"
            7z x -y -bd -o"$FIRM_DIR" "$file" >/dev/null 2>&1
            rm -f "$file"
        fi
    done

    # ---- XZ ----
    for file in "$FIRM_DIR"/*.xz; do
        if [ -f "$file" ]; then
            echo -e "- Extracting xz: $(basename "$file")"
            7z x -y -bd -o"$FIRM_DIR" "$file" >/dev/null 2>&1
            rm -f "$file"
        fi
    done

    # ---- MD5 rename ----
    for file in "$FIRM_DIR"/*.md5; do
        if [ -f "$file" ]; then
            mv -- "$file" "${file%.md5}"
        fi
    done

    # ---- TAR ----
    for file in "$FIRM_DIR"/*.tar; do
        if [ -f "$file" ]; then
            echo -e "- Extracting tar: $(basename "$file")"
            tar -xvf "$file" -C "$FIRM_DIR" >/dev/null 2>&1
            rm -f "$file"
        fi
    done

    # ---- LZ4 ----
    rm -rf $FIRM_DIR/{cache.img.lz4,dtbo.img.lz4,efuse.img.lz4,gz-verified.img.lz4,lk-verified.img.lz4,md1img.img.lz4,md_udc.img.lz4,misc.bin.lz4,omr.img.lz4,param.bin.lz4,preloader.img.lz4,recovery.img.lz4,scp-verified.img.lz4,spmfw-verified.img.lz4,sspm-verified.img.lz4,tee-verified.img.lz4,tzar.img.lz4,up_param.bin.lz4,userdata.img.lz4,vbmeta.img.lz4,vbmeta_system.img.lz4,audio_dsp-verified.img.lz4,cam_vpu1-verified.img.lz4,cam_vpu2-verified.img.lz4,cam_vpu3-verified.img.lz4,dpm-verified.img.lz4,init_boot.img.lz4,mcupm-verified.img.lz4,pi_img-verified.img.lz4,uh.bin.lz4,vendor_boot.img.lz4}
    for file in "$FIRM_DIR"/*.lz4; do
        if [ -f "$file" ]; then
            echo -e "- Extracting lz4: $(basename "$file")"
            lz4 -d "$file" "${file%.lz4}" >/dev/null 2>&1
            rm -f "$file"
        fi
    done

    # ---- REMOVE UNWANTED FILES ----
    rm -rf \
        "$FIRM_DIR"/*.txt \
        "$FIRM_DIR"/*.pit \
        "$FIRM_DIR"/*.bin \
        "$FIRM_DIR"/meta-data

    # ---- SUPER.IMG ----
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

    echo -e "${YELLOW}Preparing partitions.${NC}"

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

        local partition
        local fstype
        local IMG_SIZE

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
                "$(pwd)/bin/erofs-utils/extract.erofs" -i "$imgfile" -x -f -o "$FIRM_DIR" >/dev/null 2>&1
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
        echo -e "Firmware may be corrupt or unsupported."
        exit 1
    fi

    chown -R "$REAL_USER:$REAL_USER" "$FIRM_DIR"
    chmod -R u+rwX "$FIRM_DIR"
}

FIX_SYSTEM_EXT() {
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"

    if [ "$STOCK_HAS_SEPARATE_SYSTEM_EXT" = "TRUE" ] && [ -d "$EXTRACTED_FIRM_DIR/system_ext" ]; then
        export TARGET_ROM_SYSTEM_EXT_DIR="$EXTRACTED_FIRM_DIR/system_ext"
        return 1
    fi

    if [ "$STOCK_HAS_SEPARATE_SYSTEM_EXT" = "FALSE" ] && [[ -d "$EXTRACTED_FIRM_DIR/system_ext" ]]; then
        echo -e "- Copying system_ext content into system root"
        rm -rf "$EXTRACTED_FIRM_DIR/system/system_ext"
        cp -a --preserve=all "$EXTRACTED_FIRM_DIR/system_ext" "$EXTRACTED_FIRM_DIR/system"

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

        export TARGET_ROM_SYSTEM_EXT_DIR="$EXTRACTED_FIRM_DIR/system/system_ext"

        rm -rf "$EXTRACTED_FIRM_DIR/system_ext"
        rm -rf "$EXTRACTED_FIRM_DIR/config/system_ext_fs_config"
        rm -rf "$EXTRACTED_FIRM_DIR/config/system_ext_file_contexts"
    else
        if [ -d "$EXTRACTED_FIRM_DIR/system/system_ext/apex" ]; then
            export TARGET_ROM_SYSTEM_EXT_DIR="$EXTRACTED_FIRM_DIR/system/system_ext"
        elif [ -d "$EXTRACTED_FIRM_DIR/system/system/system_ext/apex" ]; then
            export TARGET_ROM_SYSTEM_EXT_DIR="$EXTRACTED_FIRM_DIR/system/system/system_ext"
        fi
    fi
}

FIX_SELINUX() {
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    echo -e "- Fixing selinux"

    local EXTRACTED_FIRM_DIR="$1"

    if [ -d "$EXTRACTED_FIRM_DIR/system_ext/apex" ]; then
        export TARGET_ROM_SYSTEM_EXT_DIR="$EXTRACTED_FIRM_DIR/system_ext"
    elif [ -d "$EXTRACTED_FIRM_DIR/system/system_ext/apex" ]; then
        export TARGET_ROM_SYSTEM_EXT_DIR="$EXTRACTED_FIRM_DIR/system/system_ext"
    elif [ -d "$EXTRACTED_FIRM_DIR/system/system/system_ext/apex" ]; then
        export TARGET_ROM_SYSTEM_EXT_DIR="$EXTRACTED_FIRM_DIR/system/system/system_ext"
    fi

    if [ -n "$STOCK_VNDK_VERSION" ]; then
        SELINUX_FILE="$TARGET_ROM_SYSTEM_EXT_DIR/etc/selinux/mapping/${STOCK_VNDK_VERSION}.0.cil"
    else
        MANIFEST_FILE="$TARGET_ROM_SYSTEM_EXT_DIR/etc/vintf/manifest.xml"

        if [ ! -f "$MANIFEST_FILE" ]; then
            echo -e "- manifest.xml not found. Cannot determine VNDK version."
            return 1
        fi

        STOCK_VNDK_VERSION=$(grep -oP '(?<=<version>)[0-9]+' "$MANIFEST_FILE" | head -n1)

        if [ -z "$STOCK_VNDK_VERSION" ]; then
            echo -e "- Failed to extract VNDK version from manifest."
            return 1
        fi

        SELINUX_FILE="$TARGET_ROM_SYSTEM_EXT_DIR/etc/selinux/mapping/${STOCK_VNDK_VERSION}.0.cil"
    fi

    echo -e "- Using SELinux mapping file: $SELINUX_FILE"

    if [ ! -f "$SELINUX_FILE" ]; then
        echo -e "- Error: SELinux file not found at $SELINUX_FILE"
        exit 1
    fi

    UNSUPPORTED_SELINUX=("audiomirroring" "fabriccrypto" "hal_dsms_default" "qb_id_prop" "hal_dsms_service" "proc_compaction_proactiveness" "sbauth" "ker_app" "kpp_app" "kpp_data" "attiqi_app" "kpoc_charger" "sec_diag")

    for keyword in "${UNSUPPORTED_SELINUX[@]}"; do
        if grep -q "$keyword" "$SELINUX_FILE"; then
            sed -i "/$keyword/d" "$SELINUX_FILE"
        fi
    done

    REMOVE_LINE '(genfscon sysfs "/bus/usb/devices" (u object_r sysfs_usb ((s0) (s0))))' "$EXTRACTED_FIRM_DIR/system/system/etc/selinux/plat_sepolicy.cil" >/dev/null 2>&1
    REMOVE_LINE '(genfscon proc "/sys/vm/compaction_proactiveness" (u object_r proc_compaction_proactiveness ((s0) (s0))))' "$EXTRACTED_FIRM_DIR/system/system/etc/selinux/plat_sepolicy.cil" >/dev/null 2>&1
    REMOVE_LINE '(genfscon proc "/sys/kernel/firmware_config" (u object_r proc_fmw ((s0) (s0))))' "$TARGET_ROM_SYSTEM_EXT_DIR/etc/selinux/system_ext_sepolicy.cil" >/dev/null 2>&1
    REMOVE_LINE '(genfscon proc "/sys/vm/compaction_proactiveness" (u object_r proc_compaction_proactiveness ((s0) (s0))))' "$TARGET_ROM_SYSTEM_EXT_DIR/etc/selinux/system_ext_sepolicy.cil" >/dev/null 2>&1
    REMOVE_LINE 'init.svc.vendor.wvkprov_server_hal                           u:object_r:wvkprov_prop:s0' "$TARGET_ROM_SYSTEM_EXT_DIR/etc/selinux/system_ext_property_contexts" >/dev/null 2>&1
}

FIX_VNDK() {
    echo -e "- Checking VNDK version."
    export SDK="$(GET_PROP "$EXTRACTED_FIRM_DIR" "system" ro.build.version.sdk)"
    echo -e "- Target ROM SDK version: $SDK"
    if [ -f "$TARGET_ROM_SYSTEM_EXT_DIR/apex/com.android.vndk.v${STOCK_VNDK_VERSION}.apex" ]; then
        echo -e "- VNDK matched."
    else
        echo -e "- VNDK mismatch. Adding SDK $SDK com.android.vndk.v${STOCK_VNDK_VERSION}.apex"
        rm -rf "$TARGET_ROM_SYSTEM_EXT_DIR/apex/"*.apex
        cp -rfa "$VNDKS_COLLECTION/$SDK/$STOCK_VNDK_VERSION/system_ext/"* "$TARGET_ROM_SYSTEM_EXT_DIR/"
    fi
}

###################################################################################################
# IMAGE BUILDING
###################################################################################################

GEN_FS_CONFIG() {
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"

    [ ! -d "$EXTRACTED_FIRM_DIR" ] && {
        echo -e "- $EXTRACTED_FIRM_DIR not found."
        return 1
    }

    [ ! -d "$EXTRACTED_FIRM_DIR/config" ] && {
        echo -e "[ERROR] config directory missing"
        return 1
    }

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
                    result+="\\$c"
                    ;;
                *)
                    result+="$c"
                    ;;
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
            if [[ "$BASENAME" == "[" ]]; then
                CONTEXT="u:object_r:system_file:s0"
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
            $(pwd)/bin/erofs-utils/mkfs.erofs --mount-point="$MOUNT_POINT" --fs-config-file="$FS_CONFIG" --file-contexts="$FILE_CONTEXTS" -z lz4hc -b 4096 -T 1199145600 "$OUT_IMG" "$SRC_DIR" >/dev/null 2>&1

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

###################################################################################################
# MODS & FRAMEWORK FUNCTIONS
###################################################################################################

# Apply stock device configuration
APPLY_STOCK_CONFIG() {
    local firm_dir="$1"
    
    if [[ -z "$STOCK_DEVICE" || "$STOCK_DEVICE" == "None" ]]; then
        echo "- No stock device specified, skipping config"
        return 0
    fi
    
    # CORRECTED: QuantumROM/Devices path
    local config_dir="$(pwd)/QuantumROM/Devices/$STOCK_DEVICE"
    
    if [[ ! -d "$config_dir" ]]; then
        echo "- Config directory not found: $config_dir"
        return 0
    fi
    
    echo "- Applying stock config for $STOCK_DEVICE"
    
    # Source device config if exists
    if [[ -f "$config_dir/config" ]]; then
        source "$config_dir/config"
    fi
    
    # Copy stock files if exists
    if [[ -d "$config_dir/Stock" ]]; then
        echo "  → Copying stock files..."
        cp -rf "$config_dir/Stock"/* "$firm_dir/" 2>/dev/null || true
    fi
    
    # Copy extra files to OUT if exists
    if [[ -d "$config_dir/extra" ]]; then
        echo "  → Copying extra files..."
        cp -rf "$config_dir/extra"/* "$(pwd)/OUT/" 2>/dev/null || true
    fi
    
    echo "- Stock config applied"
}

# Apply custom features from Mods folder
APPLY_CUSTOM_FEATURES() {
    local firm_dir="$1"
    # CORRECTED: QuantumROM/Mods path
    local mods_dir="$(pwd)/QuantumROM/Mods"
    
    if [[ ! -d "$mods_dir" ]]; then
        echo "- Mods directory not found, skipping"
        return 0
    fi
    
    echo "- Applying custom mods..."
    
    # Smart Manager CN
    if [[ -d "$mods_dir/SMART_MANAGER_CN" ]]; then
        echo "  → Applying SMART_MANAGER_CN..."
        cp -rf "$mods_dir/SMART_MANAGER_CN"/* "$firm_dir/" 2>/dev/null || true
    fi
    
    # Google Photos unlimited backup
    if [[ -d "$mods_dir/GPhotos" ]]; then
        echo "  → Applying GPhotos mod..."
        cp -rf "$mods_dir/GPhotos"/* "$firm_dir/" 2>/dev/null || true
    fi
    
    # Apps folder (AiWallpaper, ClockPackage, etc.)
    if [[ -d "$mods_dir/Apps" ]]; then
        echo "  → Applying custom apps..."
        for app_mod in "$mods_dir/Apps"/*; do
            if [[ -d "$app_mod" ]]; then
                app_name=$(basename "$app_mod")
                # Only copy if target doesn't exist (avoid overwriting stock)
                if [[ ! -d "$firm_dir/system/system/app/$app_name" && ! -d "$firm_dir/system/system/priv-app/$app_name" ]]; then
                    cp -rf "$app_mod"/* "$firm_dir/" 2>/dev/null || true
                    echo "    ✓ Added: $app_name"
                fi
            fi
        done
    fi
    
    # Tethering Apex (if USE_UI_8_TETHERING_APEX is True)
    if [[ "$USE_UI_8_TETHERING_APEX" == "True" && -d "$mods_dir/Tethering_Apex/UI-8" ]]; then
        echo "  → Applying UI-8 Tethering Apex..."
        cp -rf "$mods_dir/Tethering_Apex/UI-8"/* "$firm_dir/" 2>/dev/null || true
    fi
    
    # SDHMS mod (if STOCK_DVFS_FILENAME is set)
    if [[ -n "$STOCK_DVFS_FILENAME" && -d "$mods_dir/SDHMS" ]]; then
        echo "  → Applying SDHMS mod..."
        cp -rf "$mods_dir/SDHMS"/* "$firm_dir/" 2>/dev/null || true
    fi
    
    echo "- Custom mods applied"
}

# Install framework-res.apk to apktool
INSTALL_FRAMEWORK() {
    local apk="$1"
    if [[ ! -f "$apk" ]]; then
        echo "- framework-res.apk not found"
        return 1
    fi
    echo "- Installing framework to apktool..."
    java -jar "$APKTOOL" if "$apk" -p "$(pwd)/WORK" 2>/dev/null || true
    echo "- Framework installed"
}

# Decompile APK/JAR with apktool
DECOMPILE() {
    local tool="$1"
    local framework_dir="$2"
    local file="$3"
    local out_dir="$4"
    
    if [[ ! -f "$file" ]]; then
        echo "- File not found: $file"
        return 1
    fi
    
    local name=$(basename "${file%.*}")
    echo "- Decompiling: $name"
    java -jar "$tool" d -f --frame-path "$framework_dir" "$file" -o "$out_dir/$name" 2>/dev/null || {
        echo "- Decompilation failed for $name"
        return 1
    }
    echo "- Decompiled: $name"
}

# Recompile APK/JAR with apktool
RECOMPILE() {
    local tool="$1"
    local framework_dir="$2"
    local src_dir="$3"
    local out_dir="$4"
    
    if [[ ! -d "$src_dir" ]]; then
        echo "- Source directory not found: $src_dir"
        return 1
    fi
    
    local name=$(basename "$src_dir")
    echo "- Recompiling: $name"
    java -jar "$tool" b -f --frame-path "$framework_dir" "$src_dir" -o "$out_dir/${name}.jar" 2>/dev/null || {
        echo "- Recompilation failed for $name"
        return 1
    }
    echo "- Recompiled: $name"
}

# Edit build.prop safely
BUILD_PROP() {
    local firm_dir="$1"
    local partition="$2"
    local key="$3"
    local value="${4:-}"
    
    local prop_file=""
    case "$partition" in
        system) prop_file="$firm_dir/system/system/build.prop" ;;
        product) prop_file="$firm_dir/product/etc/build.prop" ;;
        system_ext) prop_file="$firm_dir/system_ext/etc/build.prop" ;;
        *) echo "- Unknown partition: $partition"; return 1 ;;
    esac
    
    if [[ ! -f "$prop_file" ]]; then
        echo "- build.prop not found: $prop_file"
        return 1
    fi
    
    # Update or append property
    if grep -q "^${key}=" "$prop_file"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$prop_file"
    else
        echo "${key}=${value}" >> "$prop_file"
    fi
    echo "- Set $key in $partition"
}
