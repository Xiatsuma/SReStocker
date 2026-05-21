#!/bin/bash
# =============================================================================
# SReStocker - A34 Debloat Script (Final)
# =============================================================================

: "${YELLOW:=\e[33m}"
: "${NC:=\e[0m}"

DEBLOAT_APPS=(
    "HMT" "PaymentFramework" "SamsungCalendar" "LiveTranscribe" "DigitalWellbeing"
    "Maps" "Duo" "Photos" "FactoryCameraFB" "WlanTest" "AssistantShell" "BardShell"
    "DuoStub" "GoogleCalendarSyncAdapter" "AndroidDeveloperVerifier" "AndroidGlassesCore"
    "SOAgent77" "YourPhone_Stub" "AndroidAutoStub" "SingleTakeService" "SamsungBilling"
    "AndroidSystemIntelligence" "GoogleRestore" "Messages" "SearchSelector" "AirGlance"
    "AirReadingGlass" "SamsungTTS" "ARCore" "ARDrawing" "ARZone" "BGMProvider"
    "BixbyWakeup" "BlockchainBasicKit" "Cameralyzer" "DictDiotekForSec"
    "EasymodeContactsWidget81" "Fast" "FBAppManager_NS" "FunModeSDK" "GearManagerStub"
    "KidsHome_Installer" "LinkSharing_v11" "LiveDrawing" "MAPSAgent" "MdecService"
    "MinusOnePage" "MoccaMobile" "Netflix_stub" "Notes40" "ParentalCare" "PhotoTable"
    "PlayAutoInstallConfig" "SamsungPassAutofill_v1" "SmartReminder" "SmartSwitchStub"
    "UnifiedWFC" "UniversalMDMClient" "VideoEditorLite_Dream_N" "VisionIntelligence3.7"
    "VoiceAccess" "VTCameraSetting" "WebManual" "WifiGuider" "KTAuth" "KTCustomerService"
    "KTUsimManager" "LGUMiniCustomerCenter" "LGUplusTsmProxy" "SketchBook"
    "SKTMemberShip_new" "SktUsimService" "TWorld" "AirCommand" "AppUpdateCenter"
    "AREmoji" "AREmojiEditor" "AuthFramework" "AutoDoodle" "AvatarEmojiSticker"
    "AvatarEmojiSticker_S" "Bixby" "BixbyInterpreter" "BixbyVisionFramework3.5"
    "DevGPUDriver-EX2200" "DigitalKey" "Discover" "DiscoverSEP" "EarphoneTypeC"
    "EasySetup" "FBInstaller_NS" "FBServices" "FotaAgent" "GalleryWidget"
    "GameDriver-EX2100" "GameDriver-EX2200" "GameDriver-SM8150" "HashTagService"
    "MultiControlVP6" "LedCoverService" "LinkToWindowsService" "LiveStickers"
    "MemorySaver_O_Refresh" "MultiControl" "OMCAgent5" "OneDrive_Samsung_v3"
    "OneStoreService" "SamsungCarKeyFw" "SamsungPass"
    "SettingsBixby" "SetupIndiaServicesTnC" "SKTFindLostPhone" "SKTHiddenMenu"
    "SKTMemberShip" "SKTOneStore" "SmartEye" "SmartPush" "SmartThingsKit"
    "SmartTouchCall" "SOAgent7" "SOAgent75" "SolarAudio-service" "SPPPushClient"
    "sticker" "StickerFaceARAvatar" "StoryService" "SumeNNService" "SVoiceIME"
    "SwiftkeyIme" "SwiftkeySetting" "SystemUpdate" "TADownloader" "TalkbackSE"
    "TaPackAuthFw" "TPhoneOnePackage" "TPhoneSetup" "UltraDataSaving_O" "Upday"
    "UsimRegistrationKOR" "YourPhone_P1_5" "AvatarPicker" "GpuWatchApp"
    "KT114Provider2" "KTHiddenMenu" "KTOneStore" "KTServiceAgent" "KTServiceMenu"
    "LGUGPSnWPS" "LGUHiddenMenu" "LGUOZStore" "SKTFindLostPhoneApp" "SmartPush_64"
    "SOAgent76" "TService" "vexfwk_service" "VexScanner" "LiveEffectService"
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
    echo -e "- Debloating apps + related residuals (safe mode)."

    local removed_count=0
    local skipped_protected=0

    for app in "${DEBLOAT_APPS[@]}"; do
        if IS_PROTECTED_APP "$app"; then
            echo -e "  • Skip protected token: $app"
            skipped_protected=$((skipped_protected + 1))
            continue
        fi

        if REMOVE_APP_DIRS "$EXTRACTED_FIRM_DIR" "$app"; then
            echo -e "  • Removed app payloads for token: $app"
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
    echo -e "- Removing ESIM files."
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

REMOVE_DEBLOAT_LIBS() {
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"
    echo -e "- Removing debloated app libraries."

    # Payment / Samsung Pay
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib/hidl_tlc_payment_comm_client.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib/libtlc_payment_comm.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib/libtlc_payment_direct_comm.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib/libtlc_payment_spay.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib/vendor.samsung.hardware.tlc.payment@1.0.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib64/hidl_tlc_payment_comm_client.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib64/libtlc_payment_comm.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib64/libtlc_payment_direct_comm.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib64/libtlc_payment_spay.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib64/vendor.samsung.hardware.tlc.payment@1.0.so"
    rm -rf "$EXTRACTED_FIRM_DIR/vendor/lib/vendor.samsung.hardware.tlc.payment@1.0-impl.so"
    rm -rf "$EXTRACTED_FIRM_DIR/vendor/lib/vendor.samsung.hardware.tlc.payment@1.0.so"
    rm -rf "$EXTRACTED_FIRM_DIR/vendor/lib64/vendor.samsung.hardware.tlc.payment@1.0-impl.so"
    rm -rf "$EXTRACTED_FIRM_DIR/vendor/lib64/vendor.samsung.hardware.tlc.payment@1.0.so"

    # Bixby Voice
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib64/libSamsungAPVoiceEngine.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib64/libVoiceCommandEngine.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib64/libtensorflowlite_jni_voicecommand.so"

    # Voice Changer
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib/libvoicechanger.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib64/libvoicechanger.so"

    # Voice Recognition
    rm -rf "$EXTRACTED_FIRM_DIR/system_ext/lib/libvoicerecognition.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system_ext/lib/libvoicerecognition_jni.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system_ext/lib64/libvoicerecognition.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system_ext/lib64/libvoicerecognition_jni.so"

    # GpuWatchApp
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib/libgfxgrab.gpuwatchapp.samsung.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib/libgpustat.gpuwatchapp.samsung.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib/libsysinfo.gpuwatchapp.samsung.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib64/libgfxgrab.gpuwatchapp.samsung.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib64/libgpustat.gpuwatchapp.samsung.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib64/libsysinfo.gpuwatchapp.samsung.so"

    # Audio Mirroring
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib/libaudiomirroring_jni.audiomirroring.samsung.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib64/libaudiomirroring_jni.audiomirroring.samsung.so"

    # SPen OCR/SDK (A34 has no S Pen)
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib/libSDKMoireDetector.spenocr.samsung.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib/libSDKRecognitionOCR.spenocr.samsung.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib/libSDKRecognitionText.spensdk.samsung.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib/libSDKonnxruntime.spenocr.samsung.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib64/libSDKMoireDetector.spenocr.samsung.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib64/libSDKRecognitionOCR.spenocr.samsung.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib64/libSDKRecognitionText.spensdk.samsung.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib64/libSDKonnxruntime.spenocr.samsung.so"

    # Quram codec (from debloated apps, NOT camera)
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib/libBarcodeReader.quram.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib/libSEF.quram.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib/libagifencoder.quram.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib/libimagecodec.quram.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib64/libBarcodeReader.quram.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib64/libSEF.quram.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib64/libagifencoder.quram.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib64/libimagecodec.quram.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/lib64/libsecjpegquram.so"

    # SoundTrigger (unused on A34)
    rm -rf "$EXTRACTED_FIRM_DIR/vendor/lib64/hw/android.hardware.soundtrigger3-impl.so"
    rm -rf "$EXTRACTED_FIRM_DIR/vendor/lib64/hw/android.hardware.soundtrigger@2.3-impl.so"
    rm -rf "$EXTRACTED_FIRM_DIR/vendor/lib64/hw/sound_trigger.primary.default.so"
    rm -rf "$EXTRACTED_FIRM_DIR/vendor/lib/hw/android.hardware.soundtrigger3-impl.so"
    rm -rf "$EXTRACTED_FIRM_DIR/vendor/lib/hw/android.hardware.soundtrigger@2.3-impl.so"
    rm -rf "$EXTRACTED_FIRM_DIR/vendor/lib/hw/sound_trigger.primary.default.so"

    # Renderscript (deprecated)
    rm -rf "$EXTRACTED_FIRM_DIR/vendor/lib64/hw/android.hardware.renderscript@1.0-impl.so"
    rm -rf "$EXTRACTED_FIRM_DIR/vendor/lib/hw/android.hardware.renderscript@1.0-impl.so"
}

REMOVE_UNUSED_SERVICES() {
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"
    echo -e "- Removing unused init services."

    # Debug/Logging services (eat RAM, slow boot)
    rm -rf "$EXTRACTED_FIRM_DIR/vendor/etc/init/mtklog.rc"
    rm -rf "$EXTRACTED_FIRM_DIR/vendor/etc/init/md_monitor.rc"
    rm -rf "$EXTRACTED_FIRM_DIR/vendor/etc/init/bootperf.rc"
    rm -rf "$EXTRACTED_FIRM_DIR/vendor/etc/init/boringssl_self_test.rc"
    rm -rf "$EXTRACTED_FIRM_DIR/vendor/etc/init/loghidlvendorservice.rc"
    rm -rf "$EXTRACTED_FIRM_DIR/vendor/etc/init/atrace_categories.rc"
    rm -rf "$EXTRACTED_FIRM_DIR/vendor/etc/init/vendor_flash_recovery.rc"
    rm -rf "$EXTRACTED_FIRM_DIR/vendor/etc/init/eara-io-service.rc"
    rm -rf "$EXTRACTED_FIRM_DIR/vendor/etc/init/networksetting.rc"
    rm -rf "$EXTRACTED_FIRM_DIR/system_ext/etc/init/loghidlsysservice.rc"
    rm -rf "$EXTRACTED_FIRM_DIR/system_ext/etc/init/netdiag.rc"

    # Unknown/debug services
    rm -rf "$EXTRACTED_FIRM_DIR/vendor/etc/init/gbe.rc"
    rm -rf "$EXTRACTED_FIRM_DIR/vendor/etc/init/chipinfo_init.rc"
    rm -rf "$EXTRACTED_FIRM_DIR/vendor/etc/init/emservice.rc"

    # Payment/Knox services (apps/libs already debloated)
    rm -rf "$EXTRACTED_FIRM_DIR/vendor/etc/init/vendor.samsung.hardware.tlc.payment@1.0-service.rc"
    rm -rf "$EXTRACTED_FIRM_DIR/vendor/etc/init/vendor.samsung.hardware.tlc.iccc-service.rc"
    rm -rf "$EXTRACTED_FIRM_DIR/vendor/etc/init/vendor.samsung.hardware.tlc.kg-service.rc"
    rm -rf "$EXTRACTED_FIRM_DIR/vendor/etc/init/vendor.samsung.hardware.tlc.mpos_tui@1.0-service.rc"
    rm -rf "$EXTRACTED_FIRM_DIR/vendor/etc/init/vendor.samsung.hardware.security.skpm-service.rc"
    rm -rf "$EXTRACTED_FIRM_DIR/vendor/etc/init/vendor.samsung.hardware.security.engmode@1.0-service.rc"
    rm -rf "$EXTRACTED_FIRM_DIR/vendor/etc/init/vendor.samsung.hardware.security.drk@2.0-service.rc"
    rm -rf "$EXTRACTED_FIRM_DIR/vendor/etc/init/vendor.samsung.hardware.security.hdcp.wifidisplay-default.rc"
    rm -rf "$EXTRACTED_FIRM_DIR/vendor/etc/init/wsm-service.rc"

    # Audio mirroring (app already debloated)
    rm -rf "$EXTRACTED_FIRM_DIR/system/etc/init/audiomirroring.rc"
}

DEBLOAT() {
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"
    echo -e "${YELLOW}Debloating apps and files (deep safe mode).${NC}"

    DEBLOAT_APPS_AND_RESIDUALS "$EXTRACTED_FIRM_DIR"
    REMOVE_ESIM_FILES "$EXTRACTED_FIRM_DIR"
    REMOVE_FABRIC_CRYPTO "$EXTRACTED_FIRM_DIR"
    REMOVE_DEBLOAT_LIBS "$EXTRACTED_FIRM_DIR"
    REMOVE_UNUSED_SERVICES "$EXTRACTED_FIRM_DIR"

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
