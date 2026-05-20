#!/bin/bash
# =============================================================================
# SReStocker - A34-Specific Debloat Script
# Copyright (C) 2026 Xiatsuma
# =============================================================================

: "${YELLOW:=\e[33m}"
: "${NC:=\e[0m}"

DEBLOAT_APPS=(
    # ── Google Bloat ─────────────────────────────────────────────────
    "Maps" "Duo" "DuoStub" "Photos" "Messages"
    "GoogleRestore" "GoogleCalendarSyncAdapter" "AndroidAutoStub"
    "AndroidSystemIntelligence" "SearchSelector"
    "AssistantShell" "BardShell"
    "LiveTranscribe" "DigitalWellbeing"
    "SpeechServicesByGoogle" "HotwordEnrollment"
    "AndroidDeveloperVerifier" "AndroidGlassesCore"

    # ── Samsung Bloat ────────────────────────────────────────────────
    "SamsungCalendar" "SamsungTTS" "SamsungBilling"
    "SamsungPass" "SamsungPassAutofill_v1"
    "PaymentFramework" "HMT"
    "SingleTakeService" "SmartReminder" "SmartSwitchStub"
    "VideoEditorLite_Dream_N" "VisionIntelligence3.7"
    "VoiceAccess" "VTCameraSetting" "WifiGuider"
    "UnifiedWFC" "UniversalMDMClient"
    "AppUpdateCenter" "FotaAgent"
    "EasySetup" "EarphoneTypeC"
    "OMCAgent5" "LedCoverService"
    "LinkToWindowsService" "OneDrive_Samsung_v3"
    "MultiControl" "MultiControlVP6" "MemorySaver_O_Refresh"
    "SmartThingsKit" "SmartTouchCall"
    "GalleryWidget" "HashTagService"
    "StoryService" "StickerFaceARAvatar" "sticker"
    "BlockchainBasicKit" "LinkSharing_v11"
    "Notes40" "MinusOnePage"
    "SVoiceIME" "SketchBook"
    "AirGlance" "AirReadingGlass" "AirCommand"
    "LiveDrawing" "ARDrawing"

    # ── Facebook / Microsoft / Netflix ───────────────────────────────
    "FBAppManager_NS" "FBInstaller_NS" "FBServices"
    "YourPhone_Stub" "YourPhone_P1_5"
    "Netflix_stub"
    "OneStoreService"

    # ── Bixby ────────────────────────────────────────────────────────
    "BixbyWakeup" "Bixby" "BixbyInterpreter"
    "BixbyVisionFramework3.5" "SettingsBixby"

    # ── AR / Avatar / Emoji ──────────────────────────────────────────
    "AREmoji" "AREmojiEditor" "AvatarEmojiSticker" "AvatarEmojiSticker_S"
    "AutoDoodle" "AuthFramework" "AvatarPicker"
    "ARCore" "ARZone" "LiveStickers"

    # ── Kids / Parental ──────────────────────────────────────────────
    "KidsHome_Installer" "ParentalCare"

    # ── Misc Samsung Junk ────────────────────────────────────────────
    "FactoryCameraFB" "WlanTest"
    "BGMProvider" "Cameralyzer" "DictDiotekForSec"
    "EasymodeContactsWidget81" "Fast" "FunModeSDK"
    "GearManagerStub" "MdecService" "MoccaMobile"
    "PhotoTable" "PlayAutoInstallConfig"
    "WebManual" "SOAgent7" "SOAgent75" "SOAgent76" "SOAgent77"
    "SPPPushClient"
    "SamsungCarKeyFw" "DigitalKey"
    "SystemUpdate" "TADownloader" "TalkbackSE"
    "UltraDataSaving_O" "GpuWatchApp"
    "Discover" "DiscoverSEP"
    "SwiftkeyIme" "SwiftkeySetting"

    # ── Prism Bloat ──────────────────────────────────────────────────
    "AmazonMDIP" "appcloud_oobe"
)

PROTECTED_APP_TOKENS=(
    "DeviceServices" "DeviceService"
    "Knox" "Security" "Fmm" "FindMyMobile"
    "SetupWizard" "Provision" "ManagedProvisioning"
    "TeleService" "MmsService" "CarrierConfig"
    "SystemUI" "Settings" "framework-res"
    "PackageInstaller" "PermissionController"
    "GoogleServicesFramework" "Phonesky"
    "SamsungCamera"
)

IS_PROTECTED_APP() {
    local app="$1"
    for token in "${PROTECTED_APP_TOKENS[@]}"; do
        [[ "$app" == *"$token"* ]] && return 0
    done
    return 1
}

REMOVE_PATH_IF_EXISTS() {
    local path="$1"
    if [[ -e "$path" ]]; then
        rm -rf "$path" || echo "[WARN] Failed to remove: $path"
    fi
}

REMOVE_APP_DIRS() {
    local root="$1"
    local app_token="$2"

    local APP_DIRS=(
        "$root/system/system/app"
        "$root/system/system/priv-app"
        "$root/product/app"
        "$root/product/priv-app"
        "$root/system_ext/app"
        "$root/system_ext/priv-app"
        "$root/vendor/app"
        "$root/vendor/priv-app"
        "$root/odm/app"
        "$root/odm/priv-app"
        "$root/prism/app"
        "$root/prism/priv-app"
    )

    local removed=0
    for dir in "${APP_DIRS[@]}"; do
        [[ -d "$dir" ]] || continue
        while IFS= read -r -d '' candidate; do
            REMOVE_PATH_IF_EXISTS "$candidate"
            removed=1
        done < <(find "$dir" -mindepth 1 -maxdepth 1 -type d -iname "*${app_token}*" -print0 2>/dev/null)
    done

    return $removed
}

REMOVE_APP_RESIDUALS() {
    local root="$1"
    local app_token="$2"

    local CONFIG_DIRS=(
        "$root/system/system/etc/permissions"
        "$root/system/system/etc/default-permissions"
        "$root/system/system/etc/sysconfig"
        "$root/product/etc/permissions"
        "$root/product/etc/default-permissions"
        "$root/product/etc/sysconfig"
        "$root/system_ext/etc/permissions"
        "$root/system_ext/etc/default-permissions"
        "$root/system_ext/etc/sysconfig"
        "$root/vendor/etc/permissions"
        "$root/vendor/etc/default-permissions"
        "$root/vendor/etc/sysconfig"
        "$root/odm/etc/permissions"
        "$root/odm/etc/default-permissions"
        "$root/odm/etc/sysconfig"
        "$root/prism/etc/permissions"
        "$root/prism/etc/default-permissions"
        "$root/prism/etc/sysconfig"
    )

    for cfg in "${CONFIG_DIRS[@]}"; do
        [[ -d "$cfg" ]] || continue
        while IFS= read -r -d '' f; do
            REMOVE_PATH_IF_EXISTS "$f"
        done < <(find "$cfg" -type f -iname "*${app_token}*.xml" -print0 2>/dev/null)
    done

    while IFS= read -r -d '' oat_dir; do
        REMOVE_PATH_IF_EXISTS "$oat_dir"
    done < <(find "$root" -type d -iname "*${app_token}*" -path "*/oat/*" -print0 2>/dev/null)
}

DEBLOAT_APPS_AND_RESIDUALS() {
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"
    echo -e "- Debloating apps + related residuals."

    local removed_count=0
    local skipped_protected=0

    for app in "${DEBLOAT_APPS[@]}"; do
        if IS_PROTECTED_APP "$app"; then
            skipped_protected=$((skipped_protected + 1))
            continue
        fi

        if REMOVE_APP_DIRS "$EXTRACTED_FIRM_DIR" "$app"; then
            removed_count=$((removed_count + 1))
        fi

        REMOVE_APP_RESIDUALS "$EXTRACTED_FIRM_DIR" "$app"
    done

    echo -e "  • Removed tokens: $removed_count"
    echo -e "  • Protected skips: $skipped_protected"
}

REMOVE_ESIM_FILES() {
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"
    echo -e "- Removing ESIM files (A34 has no eSIM hardware)."
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/autoinstalls/autoinstalls-com.google.android.euicc"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/default-permissions/default-permissions-com.google.android.euicc.xml"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/permissions/privapp-permissions-com.samsung.euicc.xml"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/permissions/privapp-permissions-com.samsung.android.app.esimkeystring.xml"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/permissions/privapp-permissions-com.samsung.android.app.telephonyui.esimclient.xml"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/privapp-permissions-com.samsung.android.app.telephonyui.esimclient.xml"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/sysconfig/preinstalled-packages-com.samsung.euicc.xml"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/sysconfig/preinstalled-packages-com.samsung.android.app.esimkeystring.xml"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/EsimClient"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/EsimKeyString"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/EuiccService"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/EuiccGoogle"
}

REMOVE_FABRIC_CRYPTO() {
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"
    echo -e "- Removing fabric crypto."
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/bin/fabric_crypto"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/init/fabric_crypto.rc"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/permissions/FabricCryptoLib.xml"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/vintf/manifest/fabric_crypto_manifest.xml"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/framework/FabricCryptoLib.jar"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/framework/oat/arm/FabricCryptoLib.odex"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/framework/oat/arm/FabricCryptoLib.vdex"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/framework/oat/arm64/FabricCryptoLib.odex"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/framework/oat/arm64/FabricCryptoLib.vdex"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/lib64/com.samsung.security.fabric.cryptod-V1-cpp.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/lib64/vendor.samsung.hardware.security.fkeymaster-V1-ndk.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/KmxService"
}

REMOVE_SWIFTKEY_DATA() {
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"
    echo -e "- Removing SwiftKey keyboard data."
    rm -rf "$EXTRACTED_FIRM_DIR/prism/sipdb/SwiftKey"
    rm -rf "$EXTRACTED_FIRM_DIR/prism/sipdb/Xt9"
    rm -rf "$EXTRACTED_FIRM_DIR/prism/HWRDB"
}

DEBLOAT() {
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"
    echo -e "${YELLOW}Debloating (A34 deep safe mode).${NC}"

    DEBLOAT_APPS_AND_RESIDUALS "$EXTRACTED_FIRM_DIR"
    REMOVE_ESIM_FILES "$EXTRACTED_FIRM_DIR"
    REMOVE_FABRIC_CRYPTO "$EXTRACTED_FIRM_DIR"
    REMOVE_SWIFTKEY_DATA "$EXTRACTED_FIRM_DIR"

    echo -e "- Deleting additional unnecessary files and folders."
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/app"/SamsungTTS*
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/init/boot-image.bprof"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/init/boot-image.prof"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/mediasearch"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/hidden"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/preload"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/MediaSearch"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app"/GameDriver-*
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/tts"
    rm -rf "$EXTRACTED_FIRM_DIR/product/app/Gmail2/oat"
    rm -rf "$EXTRACTED_FIRM_DIR/product/app/Maps/oat"
    rm -rf "$EXTRACTED_FIRM_DIR/product/app/SpeechServicesByGoogle/oat"
    rm -rf "$EXTRACTED_FIRM_DIR/product/app/YouTube/oat"
    rm -rf "$EXTRACTED_FIRM_DIR/product/priv-app"/HotwordEnrollment*

    echo -e "- Debloat complete"
}
