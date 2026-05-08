#!/bin/bash
# SReStocker independent rule-driven SELinux patch engine

SELINUX_RULES_DIR="$(pwd)/rules/selinux"

log_w() { echo "[WARN] $*" >&2; }
log_e() { echo "[ERROR] $*" >&2; }

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

remove_exact_line() {
    local file="$1"
    local line="$2"
    [[ -f "$file" ]] || return 0
    local tmp="${file}.tmp.$$"
    if ! grep -vxF "$line" "$file" > "$tmp"; then
        cp -f "$file" "$tmp"
    fi
    mv -f "$tmp" "$file"
}

append_if_missing() {
    local file="$1"
    local line="$2"
    [[ -f "$file" ]] || return 0
    grep -qxF "$line" "$file" || echo "$line" >> "$file"
}

detect_system_ext_dir() {
    local root="$1"
    if [[ -d "$root/system_ext/apex" ]]; then
        echo "$root/system_ext"; return 0
    fi
    if [[ -d "$root/system/system_ext/apex" ]]; then
        echo "$root/system/system_ext"; return 0
    fi
    if [[ -d "$root/system/system/system_ext/apex" ]]; then
        echo "$root/system/system/system_ext"; return 0
    fi
    return 1
}

detect_vndk_version() {
    local system_ext="$1"

    if [[ -n "${STOCK_VNDK_VERSION:-}" ]]; then
        echo "$STOCK_VNDK_VERSION"
        return 0
    fi

    local manifest="$system_ext/etc/vintf/manifest.xml"
    [[ -f "$manifest" ]] || return 1

    local vndk
    vndk="$(grep -oP '(?<=<version>)[0-9]+' "$manifest" | head -n1)"
    [[ -n "$vndk" ]] || return 1
    echo "$vndk"
}

apply_keyword_rules() {
    local mapping_file="$1"
    local rules="$SELINUX_RULES_DIR/keywords_drop.list"

    [[ -f "$rules" ]] || return 0
    local kw
    while IFS= read -r kw; do
        sed -i "/$kw/d" "$mapping_file"
    done < <(read_non_comment_lines "$rules")
}

apply_exact_drop_rules() {
    local root="$1"
    local rules="$SELINUX_RULES_DIR/exact_drop.list"

    [[ -f "$rules" ]] || return 0
    local entry rel line file
    while IFS= read -r entry; do
        [[ "$entry" == *"|"* ]] || continue
        rel="${entry%%|*}"
        line="${entry#*|}"
        [[ -n "$rel" && -n "$line" ]] || continue
        file="$root/$rel"
        remove_exact_line "$file" "$line"
    done < <(read_non_comment_lines "$rules")
}

apply_append_rules() {
    local root="$1"
    local rules="$SELINUX_RULES_DIR/append_if_missing.list"

    [[ -f "$rules" ]] || return 0
    local entry rel line file
    while IFS= read -r entry; do
        [[ "$entry" == *"|"* ]] || continue
        rel="${entry%%|*}"
        line="${entry#*|}"
        [[ -n "$rel" && -n "$line" ]] || continue
        file="$root/$rel"
        append_if_missing "$file" "$line"
    done < <(read_non_comment_lines "$rules")
}

FIX_SELINUX() {
    if [[ "$#" -ne 1 ]]; then
        log_e "Usage: FIX_SELINUX <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local root="$1"
    [[ -d "$root" ]] || { log_e "Invalid firmware root: $root"; return 1; }

    local system_ext vndk mapping
    system_ext="$(detect_system_ext_dir "$root")" || { log_e "Cannot detect system_ext dir"; return 1; }
    vndk="$(detect_vndk_version "$system_ext")" || { log_e "Cannot detect VNDK version"; return 1; }

    mapping="$system_ext/etc/selinux/mapping/${vndk}.0.cil"
    [[ -f "$mapping" ]] || { log_e "Missing mapping file: $mapping"; return 1; }

    apply_keyword_rules "$mapping"
    apply_exact_drop_rules "$root"
    apply_append_rules "$root"
}
