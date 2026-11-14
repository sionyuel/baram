#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BARAM_NAME=Baram
BARAM_BUNDLE_ID=com.sionyuel.inputmethod.Baram
BARAM_DEFAULTS_SUITE=com.sionyuel.Baram
BUILD_DIR="${REPO_DIR}/build/baram"
APP_PATH="${BUILD_DIR}/Build/Products/Debug/${BARAM_NAME}.app"
INSTALL_DIR="${HOME}/Library/Input Methods"
INSTALLED_APP="${INSTALL_DIR}/${BARAM_NAME}.app"
MODE="${1:---build-only}"
BARAM_ARCHS="${GUREUM_BARAM_ARCHS:-$(uname -m)}"
BARAM_TAG="$(git -C "$REPO_DIR" describe --tags --always)"
BARAM_VERSION="${BARAM_TAG#GureumKIM-}-Debug"
PREVIOUS_BARAM_LAYOUT=''

case "$BARAM_ARCHS" in
    arm64|x86_64|'arm64 x86_64') ;;
    *) echo "Unsupported Baram architectures: $BARAM_ARCHS" >&2; exit 2 ;;
esac

usage() {
    echo "Usage: $0 [--build-only|--install|--uninstall|--help]"
    echo "Builds a separately identified Baram input method."
}

verify_baram_identity() {
    local bundle_id executable product_kind defaults_suite
    if [[ -L "$1" || ! -d "$1" ]]; then
        echo "Expected a real Baram app directory: $1" >&2
        return 1
    fi
    bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$1/Contents/Info.plist")
    executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$1/Contents/Info.plist")
    product_kind=$(/usr/libexec/PlistBuddy -c 'Print :GureumProductKind' "$1/Contents/Info.plist")
    defaults_suite=$(/usr/libexec/PlistBuddy -c 'Print :GureumDefaultsSuiteName' "$1/Contents/Info.plist")
    if [[ "$bundle_id" != "$BARAM_BUNDLE_ID" || "$executable" != "$BARAM_NAME" || \
          "$product_kind" != baram || "$defaults_suite" != "$BARAM_DEFAULTS_SUITE" ]]; then
        echo "Refusing to modify a bundle with an unexpected identity: $1" >&2
        return 1
    fi
}

verify_baram() {
    verify_baram_identity "$1" || return 1
    local icon_name icon_path retina_path icon_size retina_size
    for icon_name in baram baram2 baram3 baram3f baram390 baramrom barameng baramcm baramdv baramqw; do
        icon_path="$1/Contents/Resources/${icon_name}.png"
        retina_path="$1/Contents/Resources/${icon_name}@2x.png"
        if [[ ! -f "$icon_path" || ! -f "$retina_path" ]]; then
            echo "Missing direct Baram input-source icon: $icon_name" >&2
            return 1
        fi
        icon_size=$(/usr/bin/sips -g pixelWidth -g pixelHeight "$icon_path" 2>/dev/null | awk '/pixelWidth/{w=$2}/pixelHeight/{h=$2}END{print w "x" h}')
        retina_size=$(/usr/bin/sips -g pixelWidth -g pixelHeight "$retina_path" 2>/dev/null | awk '/pixelWidth/{w=$2}/pixelHeight/{h=$2}END{print w "x" h}')
        if [[ "$icon_size" != 22x16 || "$retina_size" != 44x32 ]]; then
            echo "Unexpected direct Baram icon size for $icon_name: $icon_size / $retina_size" >&2
            return 1
        fi
    done
}

stop_installed_baram() {
    local baram_pid executable_path
    while IFS= read -r baram_pid; do
        executable_path=$(/bin/ps -p "$baram_pid" -o comm= || true)
        if [[ "$executable_path" == "${INSTALLED_APP}/Contents/MacOS/${BARAM_NAME}" ]]; then
            /bin/kill -TERM "$baram_pid"
        fi
    done < <(/usr/bin/pgrep -x "$BARAM_NAME" || true)
}

archive_installed_baram() {
    ARCHIVED_APP=''
    if [[ -e "$INSTALLED_APP" || -L "$INSTALLED_APP" ]]; then
        verify_baram_identity "$INSTALLED_APP"
        stop_installed_baram
        local backup_root
        backup_root="${HOME}/Library/Application Support/Baram/Backups"
        mkdir -p "$backup_root"
        local backup_dir
        backup_dir=$(mktemp -d "${backup_root}/baram.XXXXXX")
        mv "$INSTALLED_APP" "${backup_dir}/${BARAM_NAME}.app"
        ARCHIVED_APP="${backup_dir}/${BARAM_NAME}.app"
        echo "Previous Baram bundle preserved at $ARCHIVED_APP"
    fi
}

case "$MODE" in
    --help) usage; exit 0 ;;
    --build-only|--install) ;;
    --uninstall)
        archive_installed_baram
        echo "Baram removed. Select your regular input source."
        exit 0
        ;;
    *) usage >&2; exit 2 ;;
esac

if [[ "$MODE" == --install && -d "$INSTALLED_APP" ]]; then
    previous_source=$("${SCRIPT_DIR}/baram_input_source.sh" current 2>/dev/null || true)
    if [[ "$previous_source" == "${BARAM_BUNDLE_ID}."* ]]; then
        PREVIOUS_BARAM_LAYOUT="${previous_source#"${BARAM_BUNDLE_ID}".}"
    fi
fi

cd "$REPO_DIR"
xcodebuild -project Gureum.xcodeproj -scheme OSX -configuration Debug \
    -sdk macosx -destination 'platform=macOS' -derivedDataPath "$BUILD_DIR" \
    -onlyUsePackageVersionsFromResolvedFile GUREUM_VARIANT=BARAM \
    ARCHS="$BARAM_ARCHS" ONLY_ACTIVE_ARCH=NO \
    VERSION="$BARAM_VERSION" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build

verify_baram "$APP_PATH"

/usr/bin/codesign --force --deep --sign - --timestamp=none "$APP_PATH"
/usr/bin/codesign --verify --deep --strict "$APP_PATH"
echo "Verified Baram build: $APP_PATH"

if [[ "$MODE" == --install ]]; then
    mkdir -p "$INSTALL_DIR"
    staging_dir=$(mktemp -d "${INSTALL_DIR}/.Baram-install.XXXXXX")
    /usr/bin/ditto "$APP_PATH" "${staging_dir}/${BARAM_NAME}.app"
    verify_baram "${staging_dir}/${BARAM_NAME}.app"
    archive_installed_baram
    if ! mv "${staging_dir}/${BARAM_NAME}.app" "$INSTALLED_APP"; then
        if [[ -n "$ARCHIVED_APP" && -d "$ARCHIVED_APP" ]]; then mv "$ARCHIVED_APP" "$INSTALLED_APP"; fi
        exit 1
    fi
    rmdir "$staging_dir"
    if ! verify_baram "$INSTALLED_APP" || ! /usr/bin/codesign --verify --deep --strict "$INSTALLED_APP"; then
        failed_dir=$(mktemp -d "${HOME}/Library/Application Support/Baram/Backups/failed.XXXXXX")
        mv "$INSTALLED_APP" "${failed_dir}/${BARAM_NAME}.app"
        if [[ -n "$ARCHIVED_APP" && -d "$ARCHIVED_APP" ]]; then mv "$ARCHIVED_APP" "$INSTALLED_APP"; fi
        exit 1
    fi
    /usr/bin/codesign --verify --deep --strict "$INSTALLED_APP"
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
        -f "$INSTALLED_APP"
    if [[ -n "$PREVIOUS_BARAM_LAYOUT" ]]; then
        /usr/bin/killall TextInputMenuAgent 2>/dev/null || true
        /usr/bin/killall SystemUIServer 2>/dev/null || true
        /bin/sleep 2
        /usr/bin/open "$INSTALLED_APP"
        /bin/sleep 1
        "${SCRIPT_DIR}/baram_input_source.sh" activate "$PREVIOUS_BARAM_LAYOUT"
    fi
    if ! "${SCRIPT_DIR}/baram_input_source.sh" list >/dev/null; then
        echo "Automatic input-source registration is pending; log out and back in if needed." >&2
    fi
    echo "Installed: $INSTALLED_APP"
    echo "Add a Baram input source in System Settings > Keyboard > Text Input."
    echo "If it is not listed yet, log out and back in."
fi
