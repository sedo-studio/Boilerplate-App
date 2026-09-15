#!/usr/bin/env bash
# ============================================================================
#  setup.sh -- The Swift Kit interactive configuration wizard
# ============================================================================
#  Run:  chmod +x setup.sh && ./setup.sh
#  Or non-interactive:  ./setup.sh --config setup-config.json
#
#  This script replaces every __PLACEHOLDER__ token across the project,
#  generates Config/Secrets.swift, configures feature flags, surface style,
#  spacing density, and updates project.yml + the Xcode project.
#
#  Designed for macOS (bash 3.2+ / zsh); uses only POSIX-safe sed invocations
#  with LC_ALL=C to avoid locale issues on Darwin.
# ============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Constants & paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
BACKUP_DIR="$PROJECT_ROOT/.setup-backup-$(date +%Y%m%d%H%M%S)"

# ---------------------------------------------------------------------------
# Color helpers (ANSI; gracefully degrades if not a tty)
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    MAGENTA='\033[0;35m'
    BOLD='\033[1m'
    DIM='\033[2m'
    RESET='\033[0m'
else
    RED='' GREEN='' YELLOW='' CYAN='' MAGENTA='' BOLD='' DIM='' RESET=''
fi

success() { printf "${GREEN}%s${RESET}\n" "$1"; }
error()   { printf "${RED}%s${RESET}\n" "$1" >&2; }
warn()    { printf "${YELLOW}%s${RESET}\n" "$1"; }
info()    { printf "${CYAN}%s${RESET}\n" "$1"; }
dim()     { printf "${DIM}%s${RESET}\n" "$1"; }

# ---------------------------------------------------------------------------
# Default values (used when user presses Enter without typing)
# ---------------------------------------------------------------------------
DEFAULT_APP_NAME="My App"
DEFAULT_BUNDLE_ID="com.example.myapp"
DEFAULT_SURFACE_STYLE="glass"
DEFAULT_SPACING_DENSITY="1.0"
DEFAULT_FEAT_ONBOARDING="true"
DEFAULT_FEAT_RADAR_UNLOCK="true"
DEFAULT_FEAT_LEFT_BEHIND="true"
DEFAULT_FEAT_REVIEW="true"
DEFAULT_REVENUECAT_KEY=""
DEFAULT_TELEMETRY_ID=""
DEFAULT_TESTFLIGHT_ID=""
DEFAULT_PRIVACY_URL="https://example.com/privacy"
DEFAULT_TERMS_URL="https://example.com/terms"

# Values to be collected
APP_NAME="" BUNDLE_ID=""
SURFACE_STYLE="" SPACING_DENSITY=""
FEAT_ONBOARDING="" FEAT_RADAR_UNLOCK="" FEAT_LEFT_BEHIND="" FEAT_REVIEW=""
REVENUECAT_KEY="" TELEMETRY_ID="" TESTFLIGHT_ID=""
PRIVACY_URL="" TERMS_URL=""

# ---------------------------------------------------------------------------
# Validation helpers
# ---------------------------------------------------------------------------
validate_bundle_id() {
    echo "$1" | LC_ALL=C grep -qE '^[a-zA-Z][a-zA-Z0-9-]*(\.[a-zA-Z][a-zA-Z0-9-]*){1,}$'
}

validate_hex_color() {
    echo "$1" | LC_ALL=C grep -qE '^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$'
}

validate_url() {
    echo "$1" | LC_ALL=C grep -qE '^https?://'
}

# ---------------------------------------------------------------------------
# Prompt helpers
# ---------------------------------------------------------------------------
prompt_value() {
    local _var_name="$1" _prompt="$2" _default="$3" _validator="${4:-none}" _value=""
    while true; do
        if [ -n "$_default" ]; then
            printf "  ${YELLOW}${BOLD}%s${RESET} ${DIM}[%s]${RESET}: " "$_prompt" "$_default"
        else
            printf "  ${YELLOW}${BOLD}%s${RESET}: " "$_prompt"
        fi
        read -r _value
        [ -z "$_value" ] && _value="$_default"
        case "$_validator" in
            bundle_id) validate_bundle_id "$_value" && break || error "    Invalid bundle ID (e.g. com.company.app)" ;;
            hex_color) validate_hex_color "$_value" && break || error "    Invalid hex color (e.g. #8A2BE2)" ;;
            url)       validate_url "$_value" && break || error "    Must start with http:// or https://" ;;
            *)         break ;;
        esac
    done
    eval "$_var_name=\"\$_value\""
}

prompt_choice() {
    local _var_name="$1" _prompt="$2" _default="$3"
    shift 3
    local _options=("$@")
    echo -e "  ${YELLOW}${BOLD}${_prompt}${RESET}"
    for i in "${!_options[@]}"; do
        if [ "${_options[$i]}" = "$_default" ]; then
            echo -e "    ${GREEN}[$((i+1))]${RESET} ${_options[$i]} ${DIM}(default)${RESET}"
        else
            echo -e "    ${GREEN}[$((i+1))]${RESET} ${_options[$i]}"
        fi
    done
    printf "  ${BOLD}Choice${RESET} ${DIM}[press Enter for default]${RESET}: "
    read -r _choice
    if [ -z "$_choice" ] || ! [[ "$_choice" =~ ^[0-9]+$ ]] || [ "$_choice" -lt 1 ] || [ "$_choice" -gt "${#_options[@]}" ]; then
        eval "$_var_name=\"$_default\""
    else
        eval "$_var_name=\"${_options[$((_choice-1))]}\""
    fi
    echo ""
}

prompt_yn() {
    local _var_name="$1" _prompt="$2" _default="$3"
    if [ "$_default" = "true" ]; then
        printf "  ${YELLOW}${BOLD}%s${RESET} ${DIM}[Y/n]${RESET}: " "$_prompt"
    else
        printf "  ${YELLOW}${BOLD}%s${RESET} ${DIM}[y/N]${RESET}: " "$_prompt"
    fi
    read -r _yn
    [ -z "$_yn" ] && { eval "$_var_name=\"$_default\""; return; }
    case "$_yn" in
        [Yy]*) eval "$_var_name=true" ;;
        *)     eval "$_var_name=false" ;;
    esac
}

# ---------------------------------------------------------------------------
# Welcome banner
# ---------------------------------------------------------------------------
show_banner() {
    echo ""
    printf "${MAGENTA}${BOLD}"
    cat <<'BANNER'

 _____ _            ____          _  __ _     _  ___ _
|_   _| |__   ___  / ___|_      _(_)/ _| |_  | |/ (_) |_
  | | | '_ \ / _ \ \___ \ \ /\ / / | |_| __| | ' /| | __|
  | | | | | |  __/  ___) \ V  V /| |  _| |_  | . \| | |_
  |_| |_| |_|\___| |____/ \_/\_/ |_|_|  \__| |_|\_\_|\__|

BANNER
    printf "${RESET}"
    echo ""
    printf "${BOLD}"
    echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "       Interactive Project Setup Wizard"
    echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "${RESET}"
    echo ""
    dim "  Press Enter to accept the default value shown in [brackets]."
    dim "  You can re-run this script at any time."
    echo ""
}

# ---------------------------------------------------------------------------
# Collect all values interactively
# ---------------------------------------------------------------------------
collect_values() {
    # ── 1. App Identity ──
    echo ""
    info "── 1/5  App Identity ──"
    echo ""
    prompt_value APP_NAME  "App name" "$DEFAULT_APP_NAME"
    prompt_value BUNDLE_ID "Bundle identifier" "$DEFAULT_BUNDLE_ID" bundle_id
    prompt_value TESTFLIGHT_ID "App Store ID (for ratings, blank to skip)" "$DEFAULT_TESTFLIGHT_ID"
    echo ""

    # ── 2. Branding ──
    info "── 2/5  Branding & Design ──"
    echo ""
    dim "  Brand colours are fixed in Core/Theme/DesignSystem.swift"
    dim "  (deep indigo ground, periwinkle action colour)."
    echo ""
    prompt_choice SURFACE_STYLE "Surface style:" "$DEFAULT_SURFACE_STYLE" \
        "flat" "bordered" "elevated" "glass" "liquidGlass"
    prompt_choice SPACING_DENSITY "Spacing density:" "$DEFAULT_SPACING_DENSITY" \
        "0.85" "1.0" "1.15"

    # ── 3. Features ──
    info "── 3/5  Features ──"
    echo ""
    dim "  The finder itself (scan → \"found nearby\") is always on — it is the app."
    echo ""
    prompt_yn FEAT_ONBOARDING    "First-run onboarding?"                     "$DEFAULT_FEAT_ONBOARDING"
    prompt_yn FEAT_RADAR_UNLOCK  "Sell the radar as a one-time unlock?"      "$DEFAULT_FEAT_RADAR_UNLOCK"
    prompt_yn FEAT_LEFT_BEHIND   "Left-behind alerts (subscription)?"        "$DEFAULT_FEAT_LEFT_BEHIND"
    prompt_yn FEAT_REVIEW        "App Store review prompt after a find?"     "$DEFAULT_FEAT_REVIEW"
    echo ""
    dim "  Answering no to the radar unlock makes the radar free for everyone."
    echo ""

    # ── 4. API Keys ──
    info "── 4/5  API Keys (optional — leave blank to skip) ──"
    echo ""
    dim "  Keys go in Config/Secrets.swift (gitignored)."
    dim "  Without a RevenueCat key the app runs on a local purchase stub."
    echo ""
    prompt_value REVENUECAT_KEY "RevenueCat API key"   "$DEFAULT_REVENUECAT_KEY"
    prompt_value TELEMETRY_ID   "TelemetryDeck app ID" "$DEFAULT_TELEMETRY_ID"
    echo ""

    # ── 5. Legal ──
    info "── 5/5  Legal Links ──"
    echo ""
    prompt_value PRIVACY_URL "Privacy policy URL" "$DEFAULT_PRIVACY_URL" url
    prompt_value TERMS_URL   "Terms of service URL" "$DEFAULT_TERMS_URL" url
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
show_summary() {
    local on="${GREEN}on${RESET}" off="${DIM}off${RESET}"
    echo ""
    printf "${CYAN}${BOLD}"
    echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "                Configuration Summary"
    echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "${RESET}"
    echo ""
    printf "  %-22s ${GREEN}%s${RESET} (%s)\n" "App:" "$APP_NAME" "$BUNDLE_ID"
    printf "  %-22s ${GREEN}%s${RESET}  Density: ${GREEN}%s${RESET}\n" "Surface:" "$SURFACE_STYLE" "$SPACING_DENSITY"
    printf "  %-22s %b\n" "Onboarding:" "$([ "$FEAT_ONBOARDING" = "true" ] && echo "$on" || echo "$off")"
    printf "  %-22s %b\n" "Radar unlock (\$ once):" "$([ "$FEAT_RADAR_UNLOCK" = "true" ] && echo "$on" || echo "$off")"
    printf "  %-22s %b\n" "Left-behind alerts:" "$([ "$FEAT_LEFT_BEHIND" = "true" ] && echo "$on" || echo "$off")"
    printf "  %-22s %b\n" "Review Prompt:" "$([ "$FEAT_REVIEW" = "true" ] && echo "$on" || echo "$off")"
    echo ""
    if [ -n "$REVENUECAT_KEY" ]; then
        printf "  %-22s %s\n" "RevenueCat:" "(key set)"
    fi
    if [ -n "$TELEMETRY_ID" ]; then
        printf "  %-22s %s\n" "TelemetryDeck:" "(ID set)"
    fi
    echo ""
}

confirm_or_redo() {
    while true; do
        printf "  ${YELLOW}${BOLD}Apply these settings?${RESET} ${DIM}[Y/n]${RESET}: "
        read -r answer
        case "${answer:-y}" in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *)     warn "  Please enter y or n." ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# sed helper — handles special characters
# ---------------------------------------------------------------------------
safe_sed() {
    local escaped_replacement escaped_pattern
    escaped_replacement=$(printf '%s' "$2" | sed -e 's/[&\\/]/\\&/g')
    # Escape ONLY characters that are special in BSD/macOS basic regex (BRE).
    # NOTE: ( ) + ? { | are LITERAL in BRE — escaping them would turn them into
    # operators and break matches on text like "FeatureFlags(...)".
    escaped_pattern=$(printf '%s' "$1" | sed -e 's/[.[\/*^$\\]/\\&/g')
    LC_ALL=C sed -i '' "s/${escaped_pattern}/${escaped_replacement}/g" "$3"
}

# ---------------------------------------------------------------------------
# Apply all changes
# ---------------------------------------------------------------------------
apply_changes() {
    echo ""
    info "  Creating backup at $BACKUP_DIR ..."
    mkdir -p "$BACKUP_DIR"
    local files_to_backup=(
        "Config/AppConfig.swift"
        "Config/Secrets.sample.swift"
        "Core/Theme/DesignSystem.swift"
        "project.yml"
        "Resources/Base.lproj/Localizable.strings"
    )
    [ -f "$PROJECT_ROOT/Config/Secrets.swift" ] && files_to_backup+=("Config/Secrets.swift")
    for f in "${files_to_backup[@]}"; do
        if [ -f "$PROJECT_ROOT/$f" ]; then
            mkdir -p "$BACKUP_DIR/$(dirname "$f")"
            cp "$PROJECT_ROOT/$f" "$BACKUP_DIR/$f"
        fi
    done
    success "  Backup created."

    # ── 1. Secrets.swift ──
    info "  Generating Config/Secrets.swift ..."
    cat > "$PROJECT_ROOT/Config/Secrets.swift" <<SECRETS_EOF
//
//  Secrets.swift
//  Generated by setup.sh — do NOT commit to source control.
//

import Foundation

public enum Secrets {
    // TelemetryDeck
    public static let telemetryDeckAppID: String = "${TELEMETRY_ID}"

    // RevenueCat
    public static let revenueCatAPIKey: String = "${REVENUECAT_KEY}"
}
SECRETS_EOF
    success "  Config/Secrets.swift created."

    # ── 2. Replace __PLACEHOLDER__ tokens globally ──
    info "  Replacing template placeholders ..."

    # __APP_NAME__
    local app_files
    app_files=$(LC_ALL=C grep -rl '__APP_NAME__' "$PROJECT_ROOT" \
        --include='*.swift' --include='*.strings' --include='*.yml' --include='*.plist' \
        2>/dev/null || true)
    for f in $app_files; do
        safe_sed "__APP_NAME__" "$APP_NAME" "$f"
    done

    # __BUNDLE_ID__
    local bid_files
    bid_files=$(LC_ALL=C grep -rl '__BUNDLE_ID__' "$PROJECT_ROOT" \
        --include='*.swift' --include='*.yml' --include='*.plist' --include='*.pbxproj' \
        2>/dev/null || true)
    for f in $bid_files; do
        safe_sed "__BUNDLE_ID__" "$BUNDLE_ID" "$f"
    done

    # __PRIVACY_URL__ and __TERMS_URL__
    local legal_files
    legal_files=$(LC_ALL=C grep -rl '__PRIVACY_URL__\|__TERMS_URL__' "$PROJECT_ROOT" \
        --include='*.swift' --include='*.yml' --include='*.plist' --include='*.strings' \
        2>/dev/null || true)
    for f in $legal_files; do
        safe_sed "__PRIVACY_URL__" "$PRIVACY_URL" "$f"
        safe_sed "__TERMS_URL__" "$TERMS_URL" "$f"
    done

    # __TESTFLIGHT_APP_ID__
    if [ -n "$TESTFLIGHT_ID" ]; then
        local tf_files
        tf_files=$(LC_ALL=C grep -rl '__TESTFLIGHT_APP_ID__' "$PROJECT_ROOT" --include='*.swift' 2>/dev/null || true)
        for f in $tf_files; do
            safe_sed "__TESTFLIGHT_APP_ID__" "$TESTFLIGHT_ID" "$f"
        done
    fi

    success "  Placeholders replaced."

    # ── 3. AppConfig.swift — feature flags ──
    info "  Configuring AppConfig.swift ..."
    local cfg="$PROJECT_ROOT/Config/AppConfig.swift"

    # Rewrites the whole featureFlags line, so adding a flag to FeatureFlags.swift
    # means adding it here too or the wizard will silently drop it.
    local ff="featureFlags: FeatureFlags(onboarding: $FEAT_ONBOARDING, radarUnlock: $FEAT_RADAR_UNLOCK, leftBehindAlerts: $FEAT_LEFT_BEHIND, reviewPrompt: $FEAT_REVIEW)"
    safe_sed "featureFlags: FeatureFlags(onboarding: true, radarUnlock: true, leftBehindAlerts: true, reviewPrompt: true)" "$ff" "$cfg"

    success "  AppConfig.swift configured."

    # ── 4. DesignSystem.swift — surface style, spacing density ──
    info "  Configuring DesignSystem.swift ..."
    local ds="$PROJECT_ROOT/Core/Theme/DesignSystem.swift"

    # Surface style
    LC_ALL=C sed -i '' "s|public static let surfaceStyle: SurfaceStyle = \.[a-zA-Z]*|public static let surfaceStyle: SurfaceStyle = .$SURFACE_STYLE|g" "$ds"
    # Spacing density
    LC_ALL=C sed -i '' "s|public static let spacingDensity: CGFloat = [0-9.]*|public static let spacingDensity: CGFloat = $SPACING_DENSITY|g" "$ds"

    success "  DesignSystem.swift configured."

    # ── 5. project.yml — bundle ID, project name ──
    info "  Updating project.yml ..."
    safe_sed "com.agaganorg.theswiftkit" "$BUNDLE_ID" "$PROJECT_ROOT/project.yml"

    # Rename project & targets if different
    if [ "$APP_NAME" != "TheSwiftKit" ]; then
        # Only rename if still using the original name
        if grep -q "name: TheSwiftKit" "$PROJECT_ROOT/project.yml" 2>/dev/null; then
            # Clean app name for target (remove spaces)
            local TARGET_NAME
            TARGET_NAME=$(echo "$APP_NAME" | tr -d ' ')
            LC_ALL=C sed -i '' "s|name: TheSwiftKit|name: $TARGET_NAME|g" "$PROJECT_ROOT/project.yml"
            LC_ALL=C sed -i '' "s|TheSwiftKit:|${TARGET_NAME}:|g" "$PROJECT_ROOT/project.yml"
            LC_ALL=C sed -i '' "s|TheSwiftKitTests|${TARGET_NAME}Tests|g" "$PROJECT_ROOT/project.yml"
            LC_ALL=C sed -i '' "s|- target: TheSwiftKit|- target: ${TARGET_NAME}|g" "$PROJECT_ROOT/project.yml"
        fi
    fi

    success "  project.yml updated."

    # ── 6. Update Xcode pbxproj if present ──
    local pbxproj="$PROJECT_ROOT/TheSwiftKit.xcodeproj/project.pbxproj"
    if [ -f "$pbxproj" ]; then
        info "  Updating bundle ID in project.pbxproj ..."
        safe_sed "com.agaganorg.theswiftkit" "$BUNDLE_ID" "$pbxproj"
        success "  project.pbxproj updated."
    fi

    # ── 7. Regenerate Xcode project ──
    if command -v xcodegen &> /dev/null; then
        info "  Regenerating Xcode project ..."
        cd "$PROJECT_ROOT"
        xcodegen generate --quiet 2>/dev/null || xcodegen generate
        success "  Xcode project regenerated."
    else
        warn "  xcodegen not found. Install with: brew install xcodegen"
        warn "  Then run: xcodegen generate"
    fi
}

# ---------------------------------------------------------------------------
# Completion message
# ---------------------------------------------------------------------------
show_completion() {
    echo ""
    printf "${GREEN}${BOLD}"
    echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "              Setup Complete!"
    echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "${RESET}"
    echo ""
    echo -e "  ${BOLD}Next steps:${RESET}"
    echo ""

    # Detect project name
    local proj_name="TheSwiftKit"
    if [ "$APP_NAME" != "TheSwiftKit" ]; then
        proj_name=$(echo "$APP_NAME" | tr -d ' ')
    fi

    echo -e "    1. Open ${CYAN}${proj_name}.xcodeproj${RESET} in Xcode"
    echo "    2. Select your team in Signing & Capabilities"
    echo -e "    3. Press ${GREEN}Cmd+R${RESET} to run"
    echo ""
    echo -e "  ${BOLD}Files configured:${RESET}"
    echo -e "    ${DIM}Config/AppConfig.swift        — app name, features, branding${RESET}"
    echo -e "    ${DIM}Config/Secrets.swift          — API keys${RESET}"
    echo -e "    ${DIM}Core/Theme/DesignSystem.swift — palette, surface style, density${RESET}"
    echo -e "    ${DIM}project.yml                   — project name, bundle ID${RESET}"
    echo ""
    echo -e "  ${DIM}To change the theme later, edit Core/Theme/DesignSystem.swift${RESET}"
    echo -e "  ${DIM}To change features, edit Config/AppConfig.swift (featureFlags section)${RESET}"
    echo ""
    if [ -n "$REVENUECAT_KEY" ]; then
        warn "  RevenueCat setup reminder:"
        echo "    Create two entitlements: 'radar_unlock' (non-consumable) and"
        echo "    'left_behind_alerts' (auto-renewing subscription), each served by"
        echo "    an offering of the same name. See documentation/MONETIZATION.md."
        echo ""
    fi
    dim "  Backup saved to: $BACKUP_DIR"
    echo ""
}

# ---------------------------------------------------------------------------
# Non-interactive mode: load from JSON
# ---------------------------------------------------------------------------
load_from_json() {
    local config_file="$1"
    [ ! -f "$config_file" ] && { error "Config file not found: $config_file"; exit 1; }

    local python_cmd="python3"
    command -v python3 &>/dev/null || { [ -x /usr/bin/python3 ] && python_cmd="/usr/bin/python3"; } || { error "python3 required for --config mode"; exit 1; }

    json_val() {
        $python_cmd -c "
import json, sys
with open('$config_file') as f:
    d = json.load(f)
print(d.get('$1', ''))" 2>/dev/null
    }

    APP_NAME=$(json_val app_name)
    BUNDLE_ID=$(json_val bundle_id)
    SURFACE_STYLE=$(json_val surface_style)
    SPACING_DENSITY=$(json_val spacing_density)
    FEAT_ONBOARDING=$(json_val feat_onboarding)
    FEAT_RADAR_UNLOCK=$(json_val feat_radar_unlock)
    FEAT_LEFT_BEHIND=$(json_val feat_left_behind_alerts)
    FEAT_REVIEW=$(json_val feat_review)
    REVENUECAT_KEY=$(json_val revenuecat_api_key)
    TELEMETRY_ID=$(json_val telemetrydeck_app_id)
    TESTFLIGHT_ID=$(json_val app_store_id)
    PRIVACY_URL=$(json_val privacy_url)
    TERMS_URL=$(json_val terms_url)

    # Fill defaults
    [ -z "$APP_NAME" ]         && APP_NAME="$DEFAULT_APP_NAME"
    [ -z "$BUNDLE_ID" ]        && BUNDLE_ID="$DEFAULT_BUNDLE_ID"
    [ -z "$SURFACE_STYLE" ]     && SURFACE_STYLE="$DEFAULT_SURFACE_STYLE"
    [ -z "$SPACING_DENSITY" ]   && SPACING_DENSITY="$DEFAULT_SPACING_DENSITY"
    [ -z "$FEAT_ONBOARDING" ]   && FEAT_ONBOARDING="$DEFAULT_FEAT_ONBOARDING"
    [ -z "$FEAT_RADAR_UNLOCK" ] && FEAT_RADAR_UNLOCK="$DEFAULT_FEAT_RADAR_UNLOCK"
    [ -z "$FEAT_LEFT_BEHIND" ]  && FEAT_LEFT_BEHIND="$DEFAULT_FEAT_LEFT_BEHIND"
    [ -z "$FEAT_REVIEW" ]       && FEAT_REVIEW="$DEFAULT_FEAT_REVIEW"
    [ -z "$REVENUECAT_KEY" ]    && REVENUECAT_KEY="$DEFAULT_REVENUECAT_KEY"
    [ -z "$TELEMETRY_ID" ]      && TELEMETRY_ID="$DEFAULT_TELEMETRY_ID"
    [ -z "$PRIVACY_URL" ]       && PRIVACY_URL="$DEFAULT_PRIVACY_URL"
    [ -z "$TERMS_URL" ]        && TERMS_URL="$DEFAULT_TERMS_URL"

    info "  Loaded configuration from $config_file"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    show_banner

    if [ "${1:-}" = "--config" ] && [ -n "${2:-}" ]; then
        load_from_json "$2"
        show_summary
        apply_changes
        show_completion
    else
        local confirmed=false
        while [ "$confirmed" = false ]; do
            collect_values
            show_summary
            if confirm_or_redo; then
                confirmed=true
            else
                echo ""
                warn "  Let's try again..."
            fi
        done
        apply_changes
        show_completion
    fi
}

main "$@"
