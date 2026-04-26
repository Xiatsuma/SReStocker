#!/bin/bash
# ==============================================================================
# SReStocker - Independent SELinux Reconcile Engine
# Rule-driven, local, clean-room style
#
# Uses:
#   rules/selinux/keywords_drop.list
#   rules/selinux/exact_drop.list
#   rules/selinux/append_if_missing.list
#
# exact_drop format:
#   <relative_file_path>|<exact line to remove>
#
# append_if_missing format:
#   <relative_file_path>|<line to append if missing>
#
# relative_file_path is relative to extracted firmware root.
# Example:
#   system/system/etc/selinux/plat_sepolicy.cil|(genfscon ...)
# ==============================================================================

: "${YELLOW:=\e[33m}"
: "${NC:=\e[0m}"

SELINUX_RULES_DIR="$(pwd)/rules/selinux"

log_i() { echo -e "$*"; }
log_w() { echo -e "[WARN] $*" >&2; }
log_e() { echo -e "[ERROR] $*" >&2; }

safe_remove_exact_line() {
    local file="$1"
    local exact="$2"
    [[ -f "$file" ]] || return 0

    local tmp="${file}.tmp.$$"
    if ! grep -vxF "$exact" "$file" > "$tmp"; then
        cp -f "$file" "$tmp"
    fi
    mv -f "$tmp" "$file"
}

remove_lines_containing_keyword() {
    local file="$1"
    local keyword="$2"
    [[ -f "$file" ]] || return 0
    sed -i "/${keyword}/d" "$file"
}

append_if_missing() {
    local file="$1"
    local line="$2"
    [[ -f "$file" ]] || return 0
    grep -qxF "$line" "$file" || echo "$line" >> "$file"
}

trim() {
    local s="$1"
    # shellcheck disable=SC2001
    s="$(echo "$s" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    printf '%s' "$s"
}

read_non_comment_lines() {
    local file="$1"
    [[ -f "$file" ]] || return 0

    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="$(trim "$line")"
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^# ]] && continue
        echo "$line"
    done < "$file"
}

detect_system_ext_dir() {
    local root="$1"

    if [[ -d "$root/system_ext/apex" ]]; then
        echo "$root/system_ext"
        return 0
    fi
    if [[ -d "$root/system/system_ext/apex" ]]; then
        echo "$root/system/system_ext"
        return 0
    fi
    if [[ -d "$root/system/system/system_ext/apex" ]]; then
        echo "$root/system/system/system_ext"
        return 0
    fi

    return 1
}

detect_vndk_version() {
    local system_ext_dir="$1"

    if [[ -n "${STOCK_VNDK_VERSION:-}" ]]; then
        echo "$STOCK_VNDK_VERSION"
        return 0
    fi

    local manifest="$system_ext_dir/etc/vintf/manifest.xml"
    [[ -f "$manifest" ]] || return 1

    local vndk
    vndk="$(grep -oP '(?<=<version>)[0-9]+' "$manifest" | head -n1)"
    [[ -n "$vndk" ]] || return 1

    echo "$vndk"
}

apply_keyword_rules() {
    local mapping_file="$1"
    local rules_file="$SELINUX_RULES_DIR/keywords_drop.list"

    [[ -f "$rules_file" ]] || {
        log_w "Missing $rules_file (skipping keyword drops)"
        return 0
    }

    local kw
    while IFS= read -r kw; do
        remove_lines_containing_keyword "$mapping_file" "$kw"
    done < <(read_non_comment_lines "$rules_file")
}

apply_exact_drop_rules() {
    local root="$1"
    local rules_file="$SELINUX_RULES_DIR/exact_drop.list"

    [[ -f "$rules_file" ]] || {
        log_w "Missing $rules_file (skipping exact drops)"
        return 0
    }

    local entry rel exact file
    while IFS= read -r entry; do
        rel="${entry%%|*}"
        exact="${entry#*|}"
        file="$root/$rel"

        [[ -n "$rel" && -n "$exact" ]] || continue
        safe_remove_exact_line "$file" "$exact"
    done < <(read_non_comment_lines "$rules_file")
}

apply_append_rules() {
    local root="$1"
    local rules_file="$SELINUX_RULES_DIR/append_if_missing.list"

    [[ -f "$rules_file" ]] || {
        log_w "Missing $rules_file (skipping append rules)"
        return 0
    }

    local entry rel line file
    while IFS= read -r entry; do
        rel="${entry%%|*}"
        line="${entry#*|}"
        file="$root/$rel"

        [[ -n "$rel" && -n "$line" ]] || continue
        append_if_missing "$file" "$line"
    done < <(read_non_comment_lines "$rules_file")
}

FIX_SELINUX() {
    if [[ "$#" -ne 1 ]]; then
        log_e "Usage: FIX_SELINUX <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local root="$1"
    [[ -d "$root" ]] || {
        log_e "Invalid firmware root: $root"
        return 1
    }

    log_i "${YELLOW}Applying independent SELinux reconcile engine...${NC}"

    local system_ext_dir
    system_ext_dir="$(detect_system_ext_dir "$root")" || {
        log_e "Unable to detect system_ext SELinux base dir"
        return 1
    }

    local vndk
    vndk="$(detect_vndk_version "$system_ext_dir")" || {
        log_e "Unable to detect VNDK version from system_ext manifest"
        return 1
    }

    local mapping_file="$system_ext_dir/etc/selinux/mapping/${vndk}.0.cil"
    [[ -f "$mapping_file" ]] || {
        log_e "Missing SELinux mapping file: $mapping_file"
        return 1
    }

    log_i "  • system_ext: $system_ext_dir"
    log_i "  • vndk: $vndk"
    log_i "  • mapping: $mapping_file"

    apply_keyword_rules "$mapping_file"
    apply_exact_drop_rules "$root"
    apply_append_rules "$root"

    log_i "SELinux reconcile complete."
}
