#!/bin/bash
set -euo pipefail

APP_PATH="${1:?Usage: verify_app.sh /path/to/Baram.app version}"
EXPECTED_VERSION="${2:?Specify the expected version}"
if [[ -L "$APP_PATH" || ! -d "$APP_PATH" ]]; then
    echo "Expected a real Baram app directory: $APP_PATH" >&2
    exit 1
fi
INFO_PLIST="$APP_PATH/Contents/Info.plist"
expect_property() {
    local actual
    actual=$(/usr/libexec/PlistBuddy -c "Print :$1" "$INFO_PLIST")
    if [[ "$actual" != "$2" ]]; then
        echo "Unexpected $1: $actual (expected $2)" >&2
        exit 1
    fi
}
expect_property CFBundleIdentifier com.sionyuel.inputmethod.Baram
expect_property CFBundleExecutable Baram
expect_property CFBundleVersion "$EXPECTED_VERSION"
expect_property CFBundleShortVersionString "$EXPECTED_VERSION"
expect_property GureumProductKind baram
expect_property GureumDefaultsSuiteName com.sionyuel.Baram
expect_property GureumInputSourcePrefix com.sionyuel.inputmethod.Baram
expect_property InputMethodConnectionName Baram_Connection
expect_property BaramUpdateFeedEnabled false
expect_property ComponentInputModeDict:tsInputModeListKey:com.sionyuel.inputmethod.Baram.system:tsInputModeIsVisibleKey false
if /usr/libexec/PlistBuddy -c 'Print :ComponentInputModeDict:tsVisibleInputModeOrderedArrayKey' "$INFO_PLIST" | \
    /usr/bin/grep -Fq 'com.sionyuel.inputmethod.Baram.system'; then
    echo 'Internal Roman mode must not appear in the visible input-source list.' >&2
    exit 1
fi
for binary in "$APP_PATH/Contents/MacOS/Baram" \
    "$APP_PATH/Contents/Frameworks/GureumCore.framework/GureumCore" \
    "$APP_PATH/Contents/Frameworks/Hangul.framework/Hangul"; do
    for architecture in arm64 x86_64; do
        /usr/bin/lipo -verify_arch "$architecture" "$binary"
    done
done
for icon in baram baram2 baram3 baram3f baram390 baramrom barameng baramcm baramdv baramqw; do
    for suffix in '' '@2x'; do
        icon_path="$APP_PATH/Contents/Resources/${icon}${suffix}.png"
        test -f "$icon_path"
        dimensions=$(/usr/bin/sips -g pixelWidth -g pixelHeight "$icon_path" 2>/dev/null | \
            awk '/pixelWidth/{w=$2}/pixelHeight/{h=$2}END{print w "x" h}')
        expected=22x16
        if [[ -n "$suffix" ]]; then expected=44x32; fi
        [[ "$dimensions" == "$expected" ]] || { echo "Invalid icon dimensions: $icon_path" >&2; exit 1; }
    done
done
echo "Verified Universal Baram identity, version, internal mode, disabled feed, and icons: $EXPECTED_VERSION"
