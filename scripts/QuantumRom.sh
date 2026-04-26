#!/bin/bash
set -o pipefail

YELLOW="\e[33m"
NC="\e[0m"
REAL_USER="${SUDO_USER:-$USER}"

VALID_PARTITIONS=("system" "product" "system_ext" "vendor" "odm" "system_a" "product_a" "system_ext_a" "vendor_a" "odm_a")

chmod +x "$(pwd)/bin/lp/lpunpack" 2>/dev/null || true
chmod +x "$(pwd)/bin/ext4/make_ext4fs" 2>/dev/null || true
chmod +x "$(pwd)/bin/erofs-utils/extract.erofs" 2>/dev/null || true
chmod +x "$(pwd)/bin/erofs-utils/mkfs.erofs" 2>/dev/null || true

source "$(pwd)/scripts/debloat.sh"

IS_VALID_PARTITION() {
    local n="$1"
    local p
    for p in "${VALID_PARTITIONS[@]}"; do
        [[ "$n" == "$p" ]] && return 0
    done
    return 1
}

IS_IN_BUILD_PARTITIONS() {
    local name="$1"
    IFS=',' read -r -a BUILD_LIST <<< "$BUILD_PARTITIONS"
    local p
    for p in "${BUILD_LIST[@]}"; do
        p="$(echo "$p" | xargs)"
        [[ "$name" == "$p" ]] && return 0
    done
    return 1
}

GET_PROP() {
    if [ "$#" -ne 3 ]; then
        echo "Usage: GET_PROP <EXTRACTED_DIR> <PARTITION> <PROP>"
        return 1
    fi

    local root="$1"
    local part="$2"
    local prop="$3"
    local file=""

    case "$part" in
        system) file="$root/system/system/build.prop" ;;
        product) file="$root/product/etc/build.prop" ;;
        vendor) file="$root/vendor/build.prop" ;;
        system_ext) file="$root/system_ext/etc/build.prop" ;;
        odm) file="$root/odm/etc/build.prop" ;;
        *) return 1 ;;
    esac

    [[ -f "$file" ]] || return 1
    grep -m1 "^${prop}=" "$file" | cut -d'=' -f2- || true
}

DOWNLOAD_FIRMWARE() {
    if [ "$#" -lt 4 ]; then
        echo "Usage: DOWNLOAD_FIRMWARE <MODEL> <CSC> <IMEI> <DOWNLOAD_DIRECTORY> [VERSION]"
        return 1
    fi

    local MODEL="$1"
    local CSC="$2"
    local IMEI="$3"
    local DOWN_DIR="${4}/${MODEL}"

    rm -rf "$DOWN_DIR"
    mkdir -p "$DOWN_DIR"

    [ -n "${SAMFW_URL:-}" ] || { echo "SAMFW_URL not set"; return 1; }

    local LOGF="$DOWN_DIR/wget.log"
    if ! wget --no-check-certificate -O "$DOWN_DIR/firmware.zip" "$SAMFW_URL" >"$LOGF" 2>&1; then
        tail -n 5 "$LOGF" || true
        rm -f "$LOGF"
        return 1
    fi
    rm -f "$LOGF"

    [ -f "$DOWN_DIR/firmware.zip" ] || return 1
    echo -e "${YELLOW}Firmware downloaded:${NC} $DOWN_DIR/firmware.zip"
}

EXTRACT_FIRMWARE() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: EXTRACT_FIRMWARE <FIRMWARE_DIRECTORY>"
        return 1
    fi
    local DIR="$1"

    local f
    for f in "$DIR"/*.zip; do
        [ -f "$f" ] || continue
        7z x -y -bd -o"$DIR" "$f" >/dev/null 2>&1
        rm -f "$f"
    done

    for f in "$DIR"/*.xz; do
        [ -f "$f" ] || continue
        7z x -y -bd -o"$DIR" "$f" >/dev/null 2>&1
        rm -f "$f"
    done

    for f in "$DIR"/*.md5; do
        [ -f "$f" ] || continue
        mv -- "$f" "${f%.md5}"
    done

    for f in "$DIR"/*.tar; do
        [ -f "$f" ] || continue
        tar -xf "$f" -C "$DIR" >/dev/null 2>&1
        rm -f "$f"
    done

    rm -f "$DIR"/{cache.img.lz4,dtbo.img.lz4,efuse.img.lz4,gz-verified.img.lz4,lk-verified.img.lz4,md1img.img.lz4,md_udc.img.lz4,misc.bin.lz4,omr.img.lz4,param.bin.lz4,preloader.img.lz4,recovery.img.lz4,scp-verified.img.lz4,spmfw-verified.img.lz4,sspm-verified.img.lz4,tee-verified.img.lz4,tzar.img.lz4,up_param.bin.lz4,userdata.img.lz4,vbmeta.img.lz4,vbmeta_system.img.lz4,audio_dsp-verified.img.lz4,cam_vpu1-verified.img.lz4,cam_vpu2-verified.img.lz4,cam_vpu3-verified.img.lz4,dpm-verified.img.lz4,init_boot.img.lz4,mcupm-verified.img.lz4,pi_img-verified.img.lz4,uh.bin.lz4,vendor_boot.img.lz4} 2>/dev/null || true

    for f in "$DIR"/*.lz4; do
        [ -f "$f" ] || continue
        lz4 -d "$f" "${f%.lz4}" >/dev/null 2>&1
        rm -f "$f"
    done

    rm -f "$DIR"/*.txt "$DIR"/*.pit "$DIR"/*.bin 2>/dev/null || true
    rm -rf "$DIR/meta-data" 2>/dev/null || true

    if [ -f "$DIR/super.img" ]; then
        simg2img "$DIR/super.img" "$DIR/super_raw.img"
        rm -f "$DIR/super.img"
        "$(pwd)/bin/lp/lpunpack" "$DIR/super_raw.img" "$DIR"
        rm -f "$DIR/super_raw.img"
    fi
}

PREPARE_PARTITIONS() {
    [ "$#" -eq 1 ] || return 1
    local ROOT="$1"
    [ -d "$ROOT" ] || return 1

    if [ -z "${STOCK_DEVICE:-}" ] || [ "$STOCK_DEVICE" = "None" ]; then
        export BUILD_PARTITIONS="odm,product,system_ext,system,vendor,odm_a,product_a,system_ext_a,system_a,vendor_a"
    fi

    IFS=',' read -r -a KEEP <<< "$BUILD_PARTITIONS"
    local i
    for i in "${!KEEP[@]}"; do
        KEEP[$i]="$(echo "${KEEP[$i]}" | xargs)"
    done

    shopt -s nullglob dotglob
    local item base keep_this k
    for item in "$ROOT"/*; do
        base=$(basename "$item")
        [[ "$base" == *.img ]] && base="${base%.img}"
        keep_this=0
        for k in "${KEEP[@]}"; do
            [[ "$k" == "$base" ]] && keep_this=1 && break
        done
        [[ $keep_this -eq 1 ]] || rm -rf -- "$item"
    done
    shopt -u nullglob dotglob
}

EXTRACT_FIRMWARE_IMG() {
    [ "$#" -eq 1 ] || return 1
    local DIR="$1"

    PREPARE_PARTITIONS "$DIR" || return 1

    local imgfile partition fstype desc
    for imgfile in "$DIR"/*.img; do
        [ -e "$imgfile" ] || continue
        [[ "$(basename "$imgfile")" == "boot.img" ]] && continue

        partition="$(basename "${imgfile%.img}")"
        desc="$(file -b "$imgfile")"

        if echo "$desc" | grep -qi "Android sparse image"; then
            if simg2img "$imgfile" "${imgfile}.raw" >/dev/null 2>&1; then
                mv -f "${imgfile}.raw" "$imgfile"
                desc="$(file -b "$imgfile")"
            else
                rm -f "${imgfile}.raw"
                continue
            fi
        fi

        fstype="$(blkid -o value -s TYPE "$imgfile" 2>/dev/null || true)"
        if [ -z "$fstype" ]; then
            case "$desc" in
                *EROFS*|*erofs*) fstype="erofs" ;;
                *ext4*|*Ext4*) fstype="ext4" ;;
                *f2fs*|*F2FS*) fstype="f2fs" ;;
                *) fstype="$desc" ;;
            esac
        fi

        case "$fstype" in
            ext4)
                rm -rf "$DIR/$partition"
                python3 "$(pwd)/bin/py_scripts/imgextractor.py" "$imgfile" "$DIR"
                ;;
            erofs)
                rm -rf "$DIR/$partition"
                "$(pwd)/bin/erofs-utils/extract.erofs" -i "$imgfile" -x -f -o "$DIR" >/dev/null 2>&1
                ;;
            f2fs)
                bash "$(pwd)/scripts/convert_to_ext4.sh" "$imgfile"
                rm -rf "$DIR/$partition"
                python3 "$(pwd)/bin/py_scripts/imgextractor.py" "$imgfile" "$DIR"
                ;;
            *)
                echo "Skipping unsupported fs: $partition -> $fstype"
                ;;
        esac
    done

    rm -f "$DIR"/*.img 2>/dev/null || true

    ls "$DIR"/system* >/dev/null 2>&1 || {
        echo "No system partition extracted."
        return 1
    }

    chown -R "$REAL_USER:$REAL_USER" "$DIR" 2>/dev/null || true
    chmod -R u+rwX "$DIR" 2>/dev/null || true
}

# No inline SELinux patching here.
# FIX_SELINUX is provided by scripts/selinux_engine.sh in sixteen.sh source order.

GEN_FS_CONFIG() {
    [ "$#" -eq 1 ] || return 1
    local ROOT="$1"
    [ -d "$ROOT/config" ] || return 1

    local PARTROOT PART FS_CONFIG TMP REL PATH_ENTRY
    for PARTROOT in "$ROOT"/*; do
        [ -d "$PARTROOT" ] || continue
        PART="$(basename "$PARTROOT")"
        [ "$PART" = "config" ] && continue
        IS_IN_BUILD_PARTITIONS "$PART" || continue

        FS_CONFIG="$ROOT/config/${PART}_fs_config"
        TMP="$(mktemp)"
        touch "$FS_CONFIG"
        awk '{print $1}' "$FS_CONFIG" | sort -u > "$TMP"

        find "$PARTROOT" -mindepth 1 \( -type f -o -type d -o -type l \) | while IFS= read -r item; do
            REL="${item#$PARTROOT/}"
            PATH_ENTRY="$PART/$REL"
            grep -qxF "$PATH_ENTRY" "$TMP" && continue

            if [ -d "$item" ]; then
                printf "%s 0 0 0755\n" "$PATH_ENTRY" >> "$FS_CONFIG"
            elif [[ "$REL" == */bin/* ]]; then
                printf "%s 0 2000 0755\n" "$PATH_ENTRY" >> "$FS_CONFIG"
            else
                printf "%s 0 0 0644\n" "$PATH_ENTRY" >> "$FS_CONFIG"
            fi
        done

        rm -f "$TMP"
    done
}

GEN_FILE_CONTEXTS() {
    [ "$#" -eq 1 ] || return 1
    local ROOT="$1"
    [ -d "$ROOT/config" ] || return 1

    escape_path() {
        local path="$1" out="" c i
        for ((i=0;i<${#path};i++)); do
            c="${path:i:1}"
            case "$c" in
                '.'|'+'|'['|']'|'*'|'?'|'^'|'$'|'\\') out+="\\$c" ;;
                *) out+="$c" ;;
            esac
        done
        printf '%s' "$out"
    }

    local PARTROOT PART FC REL PATH_ENTRY ESC BASENAME CTX
    for PARTROOT in "$ROOT"/*; do
        [ -d "$PARTROOT" ] || continue
        PART="$(basename "$PARTROOT")"
        [ "$PART" = "config" ] && continue
        IS_IN_BUILD_PARTITIONS "$PART" || continue

        FC="$ROOT/config/${PART}_file_contexts"
        touch "$FC"

        declare -A EXISTING=()
        while IFS= read -r line || [[ -n "$line" ]]; do
            [ -z "$line" ] && continue
            EXISTING["$(echo "$line" | awk '{print $1}')"]=1
        done < "$FC"

        find "$PARTROOT" -mindepth 1 \( -type f -o -type d -o -type l \) | while IFS= read -r item; do
            REL="${item#$PARTROOT}"
            PATH_ENTRY="/$PART$REL"
            ESC="/$(escape_path "${PATH_ENTRY#/}")"
            [[ -n "${EXISTING[$ESC]-}" ]] && continue

            BASENAME="$(basename "$item")"
            CTX="u:object_r:system_file:s0"
            [[ "$BASENAME" == "linker" || "$BASENAME" == "linker64" ]] && CTX="u:object_r:system_linker_exec:s0"

            printf "%s %s\n" "$ESC" "$CTX" >> "$FC"
            EXISTING["$ESC"]=1
        done
        unset EXISTING
    done
}

BUILD_IMG() {
    [ "$#" -eq 3 ] || return 1
    local ROOT="$1"
    local FILE_SYSTEM="$2"
    local OUT_DIR="$3"

    GEN_FS_CONFIG "$ROOT"
    GEN_FILE_CONTEXTS "$ROOT"

    local PARTROOT PART SRC OUT_IMG FS_CONFIG FILE_CONTEXTS SIZE MOUNT
    for PARTROOT in "$ROOT"/*; do
        [ -d "$PARTROOT" ] || continue
        PART="$(basename "$PARTROOT")"
        [ "$PART" = "config" ] && continue
        IS_IN_BUILD_PARTITIONS "$PART" || continue

        SRC="$ROOT/$PART"
        OUT_IMG="$OUT_DIR/${PART}.img"
        FS_CONFIG="$ROOT/config/${PART}_fs_config"
        FILE_CONTEXTS="$ROOT/config/${PART}_file_contexts"
        SIZE=$(du -sb --apparent-size "$SRC" | awk '{printf "%.0f", $1 * 1.2}')
        MOUNT="/$PART"

        [ -f "$FS_CONFIG" ] || continue
        [ -f "$FILE_CONTEXTS" ] || continue

        sort -u "$FS_CONFIG" -o "$FS_CONFIG"
        sort -u "$FILE_CONTEXTS" -o "$FILE_CONTEXTS"

        if [[ "$FILE_SYSTEM" == "erofs" ]]; then
            "$(pwd)/bin/erofs-utils/mkfs.erofs" --mount-point="$MOUNT" --fs-config-file="$FS_CONFIG" --file-contexts="$FILE_CONTEXTS" -z lz4hc -b 4096 -T 1199145600 "$OUT_IMG" "$SRC" >/dev/null 2>&1
        elif [[ "$FILE_SYSTEM" == "ext4" ]]; then
            "$(pwd)/bin/ext4/make_ext4fs" -l "$(awk "BEGIN {printf \"%.0f\", $SIZE * 1.1}")" -J -b 4096 -S "$FILE_CONTEXTS" -C "$FS_CONFIG" -a "$MOUNT" -L "$PART" "$OUT_IMG" "$SRC"
            resize2fs -M "$OUT_IMG" >/dev/null 2>&1 || true
        fi
    done

    IFS=',' read -r -a BUILD_LIST <<< "$BUILD_PARTITIONS"
    local f fname p keep
    for f in "$OUT_DIR"/*; do
        [ -f "$f" ] || continue
        fname=$(basename "$f")
        keep=0
        for p in "${BUILD_LIST[@]}"; do
            p=$(echo "$p" | xargs)
            [[ "$fname" == "${p}.img" ]] && keep=1 && break
        done
        [ $keep -eq 1 ] || rm -f "$f"
    done
}

APPLY_STOCK_CONFIG() {
    local firm_dir="$1"

    if [[ -z "$STOCK_DEVICE" || "$STOCK_DEVICE" == "None" ]]; then
        return 0
    fi

    local config_dir="$(pwd)/QuantumROM/Devices/$STOCK_DEVICE"
    [[ -d "$config_dir" ]] || return 0

    [[ -f "$config_dir/config" ]] && source "$config_dir/config"
    [[ -d "$config_dir/Stock" ]] && cp -rf "$config_dir/Stock"/* "$firm_dir/" 2>/dev/null || true
}

APPLY_CUSTOM_FEATURES() {
    local firm_dir="$1"
    local mods_dir="$(pwd)/QuantumROM/Mods"
    [[ -d "$mods_dir" ]] || return 0

    if [[ -d "$mods_dir/Apps" ]]; then
        local app_mod app_name copy_src item item_name
        for app_mod in "$mods_dir/Apps"/*; do
            [[ -d "$app_mod" ]] || continue
            app_name=$(basename "$app_mod")
            copy_src=""

            for item in "$app_mod"/*/; do
                [[ -d "$item" ]] || continue
                item_name=$(basename "$item")
                if IS_VALID_PARTITION "$item_name"; then
                    copy_src="$app_mod"
                else
                    copy_src="$item"
                fi
                break
            done

            if [[ -n "$copy_src" && -d "$copy_src" ]]; then
                cp -rf "$copy_src"/* "$firm_dir/" 2>/dev/null || true
            fi
        done
    fi

    if [[ -n "$STOCK_DVFS_FILENAME" && -d "$mods_dir/SDHMS" ]]; then
        cp -rf "$mods_dir/SDHMS"/* "$firm_dir/" 2>/dev/null || true
    fi

    if [[ "$USE_UI_8_TETHERING_APEX" == "True" && -d "$mods_dir/Tethering_Apex/UI-8" ]]; then
        cp -rf "$mods_dir/Tethering_Apex/UI-8"/* "$firm_dir/" 2>/dev/null || true
    fi
}

INSTALL_FRAMEWORK() {
    local apk="$1"
    [[ -f "$apk" ]] || return 1
    java -jar "$APKTOOL" if "$apk" -p "$(pwd)/WORK" >/dev/null 2>&1 || true
}

DECOMPILE() {
    local tool="$1" framework_dir="$2" file="$3" out_dir="$4"
    [[ -f "$file" ]] || return 1
    local name
    name=$(basename "${file%.*}")
    java -jar "$tool" d -f --frame-path "$framework_dir" "$file" -o "$out_dir/$name" >/dev/null 2>&1
}

RECOMPILE() {
    local tool="$1" framework_dir="$2" src_dir="$3" out_dir="$4"
    [[ -d "$src_dir" ]] || return 1
    local name
    name=$(basename "$src_dir")
    java -jar "$tool" b -f --frame-path "$framework_dir" "$src_dir" -o "$out_dir/${name}.jar" >/dev/null 2>&1
}

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
        *) return 1 ;;
    esac

    [[ -f "$prop_file" ]] || return 1

    if grep -q "^${key}=" "$prop_file"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$prop_file"
    else
        echo "${key}=${value}" >> "$prop_file"
    fi
}
