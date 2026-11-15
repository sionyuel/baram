#!/bin/bash
set -euo pipefail

usage() {
    echo "Usage: $0 /absolute/path/to/Baram.app [expected-version]" >&2
}

fail() {
    echo "Baram release contract failed: $*" >&2
    exit 1
}

if [[ "${1:-}" == --help ]]; then usage; exit 0; fi
if [[ $# -lt 1 || $# -gt 2 ]]; then usage; exit 2; fi
app_path="$1"
expected_version="${2:-}"
[[ "$app_path" == /* ]] || fail 'app path must be absolute'
[[ -d "$app_path" && ! -L "$app_path" ]] || fail 'expected a real app directory'
info_plist="${app_path}/Contents/Info.plist"
[[ -f "$info_plist" ]] || fail 'Info.plist is missing'
/usr/bin/plutil -lint "$info_plist" >/dev/null

plist_value() {
    /usr/libexec/PlistBuddy -c "Print :$1" "$info_plist"
}

expect_plist() {
    local actual
    actual=$(plist_value "$1") || fail "missing plist key: $1"
    [[ "$actual" == "$2" ]] || fail "$1: expected '$2', found '$actual'"
}

expect_plist CFBundleIdentifier com.sionyuel.inputmethod.Baram
expect_plist CFBundleExecutable Baram
expect_plist GureumProductKind baram
expect_plist GureumDefaultsSuiteName com.sionyuel.Baram
expect_plist GureumInputSourcePrefix com.sionyuel.inputmethod.Baram
expect_plist InputMethodConnectionName Baram_Connection
expect_plist CFBundleSignature Barm
expect_plist BaramUpdateFeedEnabled false
expect_plist ComponentInputModeDict:tsInputModeListKey:com.sionyuel.inputmethod.Baram.system:tsInputModeIsVisibleKey false

visible_modes=$(plist_value ComponentInputModeDict:tsVisibleInputModeOrderedArrayKey)
if [[ "$visible_modes" == *com.sionyuel.inputmethod.Baram.system* ]]; then
    fail 'the internal Roman mode must stay out of the visible input-source order'
fi

app_version=$(plist_value CFBundleVersion)
[[ -n "$app_version" && "$app_version" != *Debug* ]] || fail 'Release version is empty or contains Debug'
if [[ -n "$expected_version" ]]; then
    [[ "$app_version" == "$expected_version" ]] || fail "expected version '$expected_version', found '$app_version'"
fi
expect_plist CFBundleShortVersionString "$app_version"

executable="${app_path}/Contents/MacOS/Baram"
[[ -x "$executable" ]] || fail 'Baram executable is missing'
for binary in "$executable" \
    "${app_path}/Contents/Frameworks/GureumCore.framework/Versions/A/GureumCore" \
    "${app_path}/Contents/Frameworks/Hangul.framework/Versions/A/Hangul"; do
    [[ -f "$binary" ]] || fail "runtime binary is missing: $binary"
    for architecture in arm64 x86_64; do
        /usr/bin/lipo -verify_arch "$architecture" "$binary" || fail "runtime is not universal: $binary"
    done
done

# Xcode may use a separate main dylib in development builds. Inspect every main binary
# so changing that build setting cannot accidentally ship the Debug notification.
for binary in "${app_path}/Contents/MacOS/"*; do
    [[ -f "$binary" ]] || continue
    if LC_ALL=C /usr/bin/grep -a -F -q '디버그 빌드 알림' "$binary"; then
        fail "Debug-only notification is present in $binary"
    fi
done

for icon_name in baram baram2 baram3 baram3f baram390 baramrom barameng baramcm baramdv baramqw; do
    for rendition in "$icon_name.png" "$icon_name@2x.png"; do
        icon_path="${app_path}/Contents/Resources/${rendition}"
        [[ -f "$icon_path" ]] || fail "direct input-source icon is missing: $rendition"
        dimensions=$(/usr/bin/sips -g pixelWidth -g pixelHeight "$icon_path" 2>/dev/null | \
            awk '/pixelWidth/{w=$2}/pixelHeight/{h=$2}END{print w "x" h}')
        expected_dimensions=22x16
        if [[ "$rendition" == *@2x.png ]]; then expected_dimensions=44x32; fi
        [[ "$dimensions" == "$expected_dimensions" ]] || fail "incorrect dimensions for $rendition: $dimensions"
    done
done

[[ -f "${app_path}/Contents/Resources/BaramAppIcon.icns" ]] || fail 'Baram app icon is missing'
echo "Verified Baram Release contract: $app_version; universal runtime, isolated identity, hidden Roman, disabled feed, icons, no Debug notification."
