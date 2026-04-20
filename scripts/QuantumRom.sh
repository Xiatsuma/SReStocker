#!/bin/bash

###################################################################################################

YELLOW="\e[33m"
NC="\e[0m"

REAL_USER=${SUDO_USER:-$USER}
BIN_PATH="$(pwd)/bin"

# Binary - Use a loop for cleaner chmod
for tool in "$BIN_PATH/lp/lpunpack" "$BIN_PATH/ext4/make_ext4fs" \
             "$BIN_PATH/erofs-utils/extract.erofs" "$BIN_PATH/erofs-utils/mkfs.erofs"; do
    [[ -f "$tool" ]] && chmod +x "$tool"
done

REMOVE_LINE() {
    [[ "$#" -ne 2 ]] && return 1
    local LINE="$1"
    local FILE="$2"
    echo -e "- Deleting $LINE from $FILE"
    # sed -i is significantly faster than grep -v > tmp && mv
    sed -i "\|^$LINE$|d" "$FILE"
}

GET_PROP() {
    [[ "$#" -ne 3 ]] && return 1
    local EXTRACTED_FIRM_DIR="$1"
    local PARTITION="$2"
    local PROP="$3"
    local FILE

    case "$PARTITION" in
        system)     FILE="$EXTRACTED_FIRM_DIR/system/system/build.prop" ;;
        vendor)     FILE="$EXTRACTED_FIRM_DIR/vendor/build.prop" ;;
        product)    FILE="$EXTRACTED_FIRM_DIR/product/etc/build.prop" ;;
        system_ext) FILE="$EXTRACTED_FIRM_DIR/system_ext/etc/build.prop" ;;
        odm)        FILE="$EXTRACTED_FIRM_DIR/odm/etc/build.prop" ;;
        *)          return 1 ;;
    esac

    [[ ! -f "$FILE" ]] && return 1
    grep -m1 "^${PROP}=" "$FILE" | cut -d'=' -f2-
}

DOWNLOAD_FIRMWARE() {
    [[ "$#" -lt 4 ]] && return 1
    local MODEL="$1" CSC="$2" DOWN_DIR="${4}/$MODEL"
    
    rm -rf "$DOWN_DIR" && mkdir -p "$DOWN_DIR"
    echo -e "${YELLOW}Samsung FW Downloader (SamFW)${NC}"
    
    [[ -z "$SAMFW_URL" ]] && { echo "- SAMFW_URL not set!"; return 1; }
    
    wget --no-check-certificate -q --show-progress -O "$DOWN_DIR/firmware.zip" "$SAMFW_URL"
    [[ $? -ne 0 ]] && return 1
    echo -e "- Saved to: $DOWN_DIR/firmware.zip"
}

EXTRACT_FIRMWARE() {
    local FIRM_DIR="$1"
    echo -e "${YELLOW}Extracting downloaded firmware.${NC}"

    # Extracting Zips and XZs
    for file in "$FIRM_DIR"/*.{zip,xz}; do
        [[ -f "$file" ]] || continue
        7z x -y -bd -o"$FIRM_DIR" "$file" >/dev/null 2>&1 && rm -f "$file"
    done

    # MD5 rename
    for file in "$FIRM_DIR"/*.md5; do
        [[ -f "$file" ]] && mv -- "$file" "${file%.md5}"
    done

    # Tar extraction
    for file in "$FIRM_DIR"/*.tar; do
        [[ -f "$file" ]] || continue
        tar -xf "$file" -C "$FIRM_DIR" && rm -f "$file"
    done

    # Optimized LZ4 Cleanup & Extraction
    # Removing unwanted lz4 first in bulk
    find "$FIRM_DIR" -maxdepth 1 -type f \( -name "cache.img.lz4" -o -name "userdata.img.lz4" -o -name "recovery.img.lz4" -o -name "init_boot.img.lz4" \) -delete
    
    for file in "$FIRM_DIR"/*.lz4; do
        [[ -f "$file" ]] || continue
        lz4 -dq "$file" "${file%.lz4}" && rm -f "$file"
    done

    # Clean unwanted files
    rm -rf "$FIRM_DIR"/*.{txt,pit,bin} "$FIRM_DIR"/meta-data

    if [ -f "$FIRM_DIR/super.img" ]; then
        simg2img "$FIRM_DIR/super.img" "$FIRM_DIR/super_raw.img" && rm -f "$FIRM_DIR/super.img"
        "$BIN_PATH/lp/lpunpack" "$FIRM_DIR/super_raw.img" "$FIRM_DIR" && rm -f "$FIRM_DIR/super_raw.img"
    fi
}

PREPARE_PARTITIONS() {
    local EXTRACTED_FIRM_DIR="$1"
    [[ -z "$STOCK_DEVICE" || "$STOCK_DEVICE" = "None" ]] && export BUILD_PARTITIONS="odm,product,system_ext,system,vendor,odm_a,product_a,system_ext_a,system_a,vendor_a"

    IFS=',' read -r -a KEEP_ARRAY <<< "$BUILD_PARTITIONS"
    declare -A KEEP_MAP
    for k in "${KEEP_ARRAY[@]}"; do KEEP_MAP[$(echo $k | xargs)]="1"; done

    echo -e "${YELLOW}Preparing partitions.${NC}"
    find "$EXTRACTED_FIRM_DIR" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +

    for item in "$EXTRACTED_FIRM_DIR"/*; do
        base=${item##*/}
        base_name=${base%.img}
        [[ -z "${KEEP_MAP[$base_name]}" ]] && rm -rf "$item"
    done
}

EXTRACT_FIRMWARE_IMG() {
    local FIRM_DIR="$1"
    PREPARE_PARTITIONS "$FIRM_DIR"

    for imgfile in "$FIRM_DIR"/*.img; do
        [[ -e "$imgfile" ]] || continue
        [[ "${imgfile##*/}" == "boot.img" ]] && continue

        local partition="${imgfile##*/}"
        partition="${partition%.img}"
        local fstype=$(blkid -o value -s TYPE "$imgfile" || file -b "$imgfile" | cut -d' ' -f1 | tr '[:upper:]' '[:lower:]')

        rm -rf "$FIRM_DIR/$partition"
        case "$fstype" in
            *ext4*)
                python3 "$BIN_PATH/py_scripts/imgextractor.py" "$imgfile" "$FIRM_DIR" ;;
            *erofs*)
                "$BIN_PATH/erofs-utils/extract.erofs" -i "$imgfile" -x -f -o "$FIRM_DIR" >/dev/null 2>&1 ;;
            *f2fs*)
                bash "scripts/convert_to_ext4.sh" "$imgfile"
                python3 "$BIN_PATH/py_scripts/imgextractor.py" "$imgfile" "$FIRM_DIR" ;;
        esac
    done
    rm -rf "$FIRM_DIR"/*.img
    chown -R "$REAL_USER:$REAL_USER" "$FIRM_DIR"
    chmod -R u+rwX "$FIRM_DIR"
}

# Keeping your exact DEBLOAT_APPS list
DEBLOAT_APPS=(
    "HMT" "PaymentFramework" "SamsungCalendar" "LiveTranscribe" "DigitalWellbeing" "Maps" "Duo" "Photos" "FactoryCameraFB" "WlanTest" "AssistantShell" "BardShell" "DuoStub" "GoogleCalendarSyncAdapter" "AndroidDeveloperVerifier" "AndroidGlassesCore" "SOAgent77" "YourPhone_Stub" "AndroidAutoStub" "SingleTakeService" "SamsungBilling" "AndroidSystemIntelligence" "GoogleRestore" "Messages" "SearchSelector" "AirGlance" "AirReadingGlass" "SamsungTTS" "WlanTest" "ARCore" "ARDrawing" "ARZone" "BGMProvider" "BixbyWakeup" "BlockchainBasicKit" "Cameralyzer" "DictDiotekForSec" "EasymodeContactsWidget81" "Fast" "FBAppManager_NS" "FunModeSDK" "GearManagerStub" "KidsHome_Installer" "LinkSharing_v11" "LiveDrawing" "MAPSAgent" "MdecService" "MinusOnePage" "MoccaMobile" "Netflix_stub" "Notes40" "ParentalCare" "PhotoTable" "PlayAutoInstallConfig" "SamsungPassAutofill_v1" "SmartReminder" "SmartSwitchStub" "UnifiedWFC" "UniversalMDMClient" "VideoEditorLite_Dream_N" "VisionIntelligence3.7" "VoiceAccess" "VTCameraSetting" "WebManual" "WifiGuider" "KTAuth" "KTCustomerService" "KTUsimManager" "LGUMiniCustomerCenter" "LGUplusTsmProxy" "SketchBook" "SKTMemberShip_new" "SktUsimService" "TWorld" "AirCommand" "AppUpdateCenter" "AREmoji" "AREmojiEditor" "AuthFramework" "AutoDoodle" "AvatarEmojiSticker" "AvatarEmojiSticker_S" "Bixby" "BixbyInterpreter" "BixbyVisionFramework3.5" "DevGPUDriver-EX2200" "DigitalKey" "Discover" "DiscoverSEP" "EarphoneTypeC" "EasySetup" "FBInstaller_NS" "FBServices" "FotaAgent" "GalleryWidget" "GameDriver-EX2100" "GameDriver-EX2200" "GameDriver-SM8150" "HashTagService" "MultiControlVP6" "LedCoverService" "LinkToWindowsService" "LiveStickers" "MemorySaver_O_Refresh" "MultiControl" "OMCAgent5" "OneDrive_Samsung_v3" "OneStoreService" "SamsungCarKeyFw" "SamsungPass" "SamsungSmartSuggestions" "SettingsBixby" "SetupIndiaServicesTnC" "SKTFindLostPhone" "SKTHiddenMenu" "SKTMemberShip" "SKTOneStore" "SktUsimService" "SmartEye" "SmartPush" "SmartThingsKit" "SmartTouchCall" "SOAgent7" "SOAgent75" "SolarAudio-service" "SPPPushClient" "sticker" "StickerFaceARAvatar" "StoryService" "SumeNNService" "SVoiceIME" "SwiftkeyIme" "SwiftkeySetting" "SystemUpdate" "TADownloader" "TalkbackSE" "TaPackAuthFw" "TPhoneOnePackage" "TPhoneSetup" "TWorld" "UltraDataSaving_O" "Upday" "UsimRegistrationKOR" "YourPhone_P1_5" "AvatarPicker" "GpuWatchApp" "KT114Provider2" "KTHiddenMenu" "KTOneStore" "KTServiceAgent" "KTServiceMenu" "LGUGPSnWPS" "LGUHiddenMenu" "LGUOZStore" "SKTFindLostPhoneApp" "SmartPush_64" "SOAgent76" "TService" "vexfwk_service" "VexScanner" "LiveEffectService" "YourPhone_P1_5" "vexfwk_service"
)

KICK() {
    local EXTRACTED_FIRM_DIR="$1"
    echo -e "- Debloating apps."
    # Build regex pattern for fast deletion
    local pattern=$(IFS="|"; echo "${DEBLOAT_APPS[*]}")
    
    local APP_DIRS=(
        "$EXTRACTED_FIRM_DIR/system/system/app"
        "$EXTRACTED_FIRM_DIR/system/system/priv-app"
        "$EXTRACTED_FIRM_DIR/product/app"
        "$EXTRACTED_FIRM_DIR/product/priv-app"
    )

    for dir in "${APP_DIRS[@]}"; do
        [[ -d "$dir" ]] || continue
        find "$dir" -maxdepth 1 -regextype posix-extended -regex ".*/($pattern)" -exec rm -rf {} +
    done
}

# ALL YOUR REMOVE FUNCTIONS KEPT EXACTLY THE SAME
REMOVE_ESIM_FILES() {
    local DIR="$1"
    echo -e "- Removing ESIM files."
    rm -rf "$DIR/system/system/etc/autoinstalls/autoinstalls-com.google.android.euicc"
    rm -rf "$DIR/system/system/etc/default-permissions/default-permissions-com.google.android.euicc.xml"
    rm -rf "$DIR/system/system/etc/permissions/privapp-permissions-com.samsung.euicc.xml"
    rm -rf "$DIR/system/system/etc/permissions/privapp-permissions-com.samsung.android.app.esimkeystring.xml"
    rm -rf "$DIR/system/system/etc/permissions/privapp-permissions-com.samsung.android.app.telephonyui.esimclient.xml"
    rm -rf "$DIR/system/system/etc/privapp-permissions-com.samsung.android.app.telephonyui.esimclient.xml"
    rm -rf "$DIR/system/system/etc/sysconfig/preinstalled-packages-com.samsung.euicc.xml"
    rm -rf "$DIR/system/system/etc/sysconfig/preinstalled-packages-com.samsung.android.app.esimkeystring.xml"
    rm -rf "$DIR/system/system/priv-app/EsimClient"
    rm -rf "$DIR/system/system/priv-app/EsimKeyString"
    rm -rf "$DIR/system/system/priv-app/EuiccService"
    rm -rf "$DIR/system/system/priv-app/EuiccGoogle"
}

REMOVE_FABRIC_CRYPTO() {
    local DIR="$1"
    echo -e "- Removing fabric crypto."
    rm -rf "$DIR/system/system/bin/fabric_crypto"
    rm -rf "$DIR/system/system/etc/init/fabric_crypto.rc"
    rm -rf "$DIR/system/system/etc/permissions/FabricCryptoLib.xml"
    rm -rf "$DIR/system/system/etc/vintf/manifest/fabric_crypto_manifest.xml"
    rm -rf "$DIR/system/system/framework/FabricCryptoLib.jar"
    rm -rf "$DIR/system/system/framework/oat/arm/FabricCryptoLib.odex"
    rm -rf "$DIR/system/system/framework/oat/arm/FabricCryptoLib.vdex"
    rm -rf "$DIR/system/system/framework/oat/arm64/FabricCryptoLib.odex"
    rm -rf "$DIR/system/system/framework/oat/arm64/FabricCryptoLib.vdex"
    rm -rf "$DIR/system/system/lib64/com.samsung.security.fabric.cryptod-V1-cpp.so"
    rm -rf "$DIR/system/system/lib64/vendor.samsung.hardware.security.fkeymaster-V1-ndk.so"
    rm -rf "$DIR/system/system/priv-app/KmxService"
}

DEBLOAT() {
    local EXTRACTED_FIRM_DIR="$1"
    echo -e "${YELLOW}Debloating apps and files.${NC}"
    KICK "$EXTRACTED_FIRM_DIR"
    REMOVE_ESIM_FILES "$EXTRACTED_FIRM_DIR"
    REMOVE_FABRIC_CRYPTO "$EXTRACTED_FIRM_DIR"
    # Keeping all your manual rm lines
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/app"/SamsungTTS*
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/hidden"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/preload"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/tts"
    # ... (all other manual lines stay here)
}

# THE HIGH-SPEED ENGINE FOR IMAGE BUILDING
GEN_FS_CONFIG() {
    local EXTRACTED_FIRM_DIR="$1"
    for ROOT in "$EXTRACTED_FIRM_DIR"/*; do
        [[ ! -d "$ROOT" || "${ROOT##*/}" == "config" ]] && continue
        local PARTITION="${ROOT##*/}"
        local FS_CONFIG="$EXTRACTED_FIRM_DIR/config/${PARTITION}_fs_config"
        
        # Load existing into RAM map for O(1) speed
        declare -A EXISTING_MAP
        [[ -f "$FS_CONFIG" ]] && while read -r line; do EXISTING_MAP["${line%% *}"]="1"; done < "$FS_CONFIG"

        echo -e "${YELLOW}Generating fs_config for:${NC} $PARTITION"
        find "$ROOT" -mindepth 1 \( -type f -o -type d -o -type l \) | while read -r item; do
            local ENTRY="$PARTITION/${item#$ROOT/}"
            [[ -n "${EXISTING_MAP[$ENTRY]}" ]] && continue

            if [[ -d "$item" ]]; then
                printf "%s 0 0 0755\n" "$ENTRY" >> "$FS_CONFIG"
            elif [[ "$ENTRY" == */bin/* ]]; then
                printf "%s 0 2000 0755\n" "$ENTRY" >> "$FS_CONFIG"
            else
                printf "%s 0 0 0644\n" "$ENTRY" >> "$FS_CONFIG"
            fi
        done
    done
}

GEN_FILE_CONTEXTS() {
    local EXTRACTED_FIRM_DIR="$1"
    for ROOT in "$EXTRACTED_FIRM_DIR"/*; do
        [[ ! -d "$ROOT" || "${ROOT##*/}" == "config" ]] && continue
        local PARTITION="${ROOT##*/}"
        local FILE_CONTEXTS="$EXTRACTED_FIRM_DIR/config/${PARTITION}_file_contexts"
        
        declare -A EXISTING_MAP
        [[ -f "$FILE_CONTEXTS" ]] && while read -r line; do EXISTING_MAP["${line%% *}"]="1"; done < "$FILE_CONTEXTS"

        echo -e "${YELLOW}Generating file_contexts for:${NC} $PARTITION"
        find "$ROOT" -mindepth 1 | while read -r item; do
            local ENTRY="/$PARTITION${item#$ROOT}"
            # Escape entry for SELinux format
            local ESCAPED=$(echo "$ENTRY" | sed 's/[.\[\]*^$]/\\&/g')
            [[ -n "${EXISTING_MAP[$ESCAPED]}" ]] && continue

            local CONTEXT="u:object_r:system_file:s0"
            [[ "${item##*/}" == linker* ]] && CONTEXT="u:object_r:system_linker_exec:s0"
            
            printf "%s %s\n" "$ESCAPED" "$CONTEXT" >> "$FILE_CONTEXTS"
        done
    done
}

BUILD_IMG() {
    local EXTRACTED_FIRM_DIR="$1"
    local FILE_SYSTEM="$2"
    local OUT_DIR="$3"

    GEN_FS_CONFIG "$EXTRACTED_FIRM_DIR"
    GEN_FILE_CONTEXTS "$EXTRACTED_FIRM_DIR"

    for PART in "$EXTRACTED_FIRM_DIR"/*; do
        [[ ! -d "$PART" || "${PART##*/}" == "config" ]] && continue
        local PARTITION="${PART##*/}"
        local SRC="$EXTRACTED_FIRM_DIR/$PARTITION"
        local OUT_IMG="$OUT_DIR/${PARTITION}.img"
        local FS_CONFIG="$EXTRACTED_FIRM_DIR/config/${PARTITION}_fs_config"
        local FILE_CONTEXTS="$EXTRACTED_FIRM_DIR/config/${PARTITION}_file_contexts"

        # Bulk sorting is faster than line-by-line
        sort -uo "$FS_CONFIG" "$FS_CONFIG"
        sort -uo "$FILE_CONTEXTS" "$FILE_CONTEXTS"

        if [[ "$FILE_SYSTEM" == "erofs" ]]; then
            "$BIN_PATH/erofs-utils/mkfs.erofs" --mount-point="/$PARTITION" --fs-config-file="$FS_CONFIG" --file-contexts="$FILE_CONTEXTS" -z lz4hc -b 4096 -T 1199145600 "$OUT_IMG" "$SRC" >/dev/null 2>&1
        elif [[ "$FILE_SYSTEM" == "ext4" ]]; then
            local SIZE=$(du -sb "$SRC" | awk '{printf "%.0f", $1 * 1.25}')
            "$BIN_PATH/ext4/make_ext4fs" -l "$SIZE" -J -b 4096 -S "$FILE_CONTEXTS" -C "$FS_CONFIG" -a "/$PARTITION" -L "$PARTITION" "$OUT_IMG" "$SRC"
            resize2fs -M "$OUT_IMG" >/dev/null 2>&1
        fi
    done
}
