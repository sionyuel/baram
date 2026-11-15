#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${REPO_DIR}/build/baram-release-candidate"
DIST_DIR="${REPO_DIR}/dist"
VERSION=''
ALLOW_DIRTY=false
usage() {
    echo 'Usage: tools/package_baram.sh --version 2.0.0-rc.1 [--allow-dirty]'
    echo 'Builds an unsigned ad-hoc Universal prerelease candidate; does not install or publish.'
}
while [[ $# -gt 0 ]]; do
    case "$1" in
        --version) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; VERSION="$2"; shift 2 ;;
        --allow-dirty) ALLOW_DIRTY=true; shift ;;
        --help) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+(\.[a-zA-Z0-9]+)*)?$ ]]; then
    echo 'An explicit semantic version is required, for example --version 2.0.0-rc.1.' >&2
    exit 2
fi
SOURCE_COMMIT="$(git -C "$REPO_DIR" rev-parse HEAD)"
SOURCE_DIRTY=false
if ! git -C "$REPO_DIR" diff --quiet HEAD; then
    SOURCE_DIRTY=true
    if [[ "$ALLOW_DIRTY" != true ]]; then
        echo 'Tracked worktree changes exist. Commit them or use --allow-dirty for a local candidate.' >&2
        exit 1
    fi
fi
LGPL_OBJC_DIR="${REPO_DIR}/libhangul-objc"
LGPL_C_DIR="${LGPL_OBJC_DIR}/libhangul"
LGPL_OBJC_COMMIT="$(git -C "$LGPL_OBJC_DIR" rev-parse HEAD)"
LGPL_C_COMMIT="$(git -C "$LGPL_C_DIR" rev-parse HEAD)"
verify_sources() {
    local source_dir expected_commit
    for source_dir in "$LGPL_OBJC_DIR" "$LGPL_C_DIR"; do
        expected_commit="$LGPL_OBJC_COMMIT"
        if [[ "$source_dir" == "$LGPL_C_DIR" ]]; then expected_commit="$LGPL_C_COMMIT"; fi
        if [[ "$(git -C "$source_dir" rev-parse HEAD)" != "$expected_commit" ]] || \
            ! git -C "$source_dir" diff --quiet HEAD; then
            echo "LGPL source must remain clean at the captured commit: $source_dir" >&2
            exit 1
        fi
    done
}
verify_sources
BUILD_TIME="$(date -u +%Y%m%dT%H%M%SZ)"
PACKAGE_NAME="Baram-${VERSION}-unsigned-universal"
PACKAGE_DIR="${DIST_DIR}/${PACKAGE_NAME}"
ZIP_PATH="${PACKAGE_DIR}.zip"
if [[ -e "$PACKAGE_DIR" || -e "$ZIP_PATH" || -e "${ZIP_PATH}.sha256" || \
      -L "$PACKAGE_DIR" || -L "$ZIP_PATH" || -L "${ZIP_PATH}.sha256" ]]; then
    echo "Refusing to overwrite distribution: $PACKAGE_NAME" >&2; exit 1
fi
mkdir -p "$BUILD_DIR" "$DIST_DIR"
VERSION_SNAPSHOT=$(mktemp /tmp/baram-release-version.XXXXXX)
cp "${REPO_DIR}/OSX/Version.xcconfig" "$VERSION_SNAPSHOT"
restore_version() { cp "$VERSION_SNAPSHOT" "${REPO_DIR}/OSX/Version.xcconfig"; }
trap restore_version EXIT
# Preserve the diff before Xcode generates Version.xcconfig.
SOURCE_PATCH="${BUILD_DIR}/worktree-${BUILD_TIME}.patch"
git -C "$REPO_DIR" diff --binary HEAD > "$SOURCE_PATCH"

cd "$REPO_DIR"
xcodebuild -project Gureum.xcodeproj -scheme OSX -configuration Release \
    -sdk macosx -destination 'generic/platform=macOS' -derivedDataPath "$BUILD_DIR" \
    -onlyUsePackageVersionsFromResolvedFile GUREUM_VARIANT=BARAM VERSION="$VERSION" \
    ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY='' DEVELOPMENT_TEAM='' \
    REGISTER_APP_WITH_LAUNCH_SERVICES=NO build
APP_PATH="${BUILD_DIR}/Build/Products/Release/Baram.app"
bash "${SCRIPT_DIR}/baram_distribution/verify_app.sh" "$APP_PATH" "$VERSION"
/usr/bin/codesign --force --deep --sign - --timestamp=none "$APP_PATH"
/usr/bin/codesign --verify --deep --strict "$APP_PATH"
verify_sources
if [[ "$(git -C "$REPO_DIR" rev-parse HEAD)" != "$SOURCE_COMMIT" ]]; then
    echo 'Repository HEAD changed while building; retry with a fixed source revision.' >&2
    exit 1
fi
mkdir "$PACKAGE_DIR"
/usr/bin/ditto "$APP_PATH" "${PACKAGE_DIR}/Baram.app"
cp "${SCRIPT_DIR}/baram_distribution/README.ko.md" "${PACKAGE_DIR}/README.ko.md"
mkdir "${PACKAGE_DIR}/LICENSES" "${PACKAGE_DIR}/Sources"
cp "${REPO_DIR}/COPYING" "${PACKAGE_DIR}/LICENSES/Baram-BSD.txt"
cp "${REPO_DIR}/OSX/Icons/COPYING" "${PACKAGE_DIR}/LICENSES/Gureum-icons.txt"
cp "${LGPL_OBJC_DIR}/COPYING" "${PACKAGE_DIR}/LICENSES/libhangul-objc-LGPL.txt"
cp "${LGPL_C_DIR}/COPYING" "${PACKAGE_DIR}/LICENSES/libhangul-LGPL.txt"
cp "${REPO_DIR}/Gureum.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved" \
    "${PACKAGE_DIR}/LICENSES/Package.resolved"
for dependency_dir in "${BUILD_DIR}/SourcePackages/checkouts/"*; do
    for license_name in LICENSE LICENSE.txt LICENSE.md COPYING NOTICE; do
        if [[ -f "${dependency_dir}/${license_name}" ]]; then
            cp "${dependency_dir}/${license_name}" \
                "${PACKAGE_DIR}/LICENSES/$(basename "$dependency_dir")-${license_name}"
        fi
    done
done
git -C "$REPO_DIR" archive --format=tar.gz --prefix=baram/ \
    -o "${PACKAGE_DIR}/Sources/baram-source.tar.gz" "$SOURCE_COMMIT"
cp "$SOURCE_PATCH" "${PACKAGE_DIR}/Sources/baram-worktree.patch"
git -C "$LGPL_OBJC_DIR" archive --format=tar.gz --prefix=libhangul-objc/ \
    -o "${PACKAGE_DIR}/Sources/libhangul-objc-source.tar.gz" "$LGPL_OBJC_COMMIT"
git -C "$LGPL_C_DIR" archive --format=tar.gz --prefix=libhangul/ \
    -o "${PACKAGE_DIR}/Sources/libhangul-source.tar.gz" "$LGPL_C_COMMIT"
cp "${SCRIPT_DIR}/baram_distribution/Sources-README.ko.md" "${PACKAGE_DIR}/Sources/README.ko.md"
mkdir "${PACKAGE_DIR}/Sources/PackagingTools"
cp "${SCRIPT_DIR}/package_baram.sh" "${PACKAGE_DIR}/Sources/PackagingTools/package_baram.sh"
/usr/bin/ditto "${SCRIPT_DIR}/baram_distribution" \
    "${PACKAGE_DIR}/Sources/PackagingTools/baram_distribution"
SOURCE_INFO="${BUILD_DIR}/source-provenance-${BUILD_TIME}.plist"
/usr/bin/plutil -create xml1 "$SOURCE_INFO"
for entry in "sourceCommit:$SOURCE_COMMIT" "libhangulObjcCommit:$LGPL_OBJC_COMMIT" \
    "libhangulCommit:$LGPL_C_COMMIT" \
    "libhangulObjcTree:$(git -C "$LGPL_OBJC_DIR" rev-parse "${LGPL_OBJC_COMMIT}^{tree}")" \
    "libhangulTree:$(git -C "$LGPL_C_DIR" rev-parse "${LGPL_C_COMMIT}^{tree}")"; do
    /usr/bin/plutil -insert "${entry%%:*}" -string "${entry#*:}" "$SOURCE_INFO"
done
/usr/bin/plutil -convert json -o "${PACKAGE_DIR}/Sources/source-provenance.json" "$SOURCE_INFO"
INFO_PLIST="${BUILD_DIR}/build-info-${BUILD_TIME}.plist"
/usr/bin/plutil -create xml1 "$INFO_PLIST"
for entry in "sourceCommit:$SOURCE_COMMIT" "appVersion:$VERSION" "builtAtUTC:$BUILD_TIME" \
    'architecture:arm64 x86_64' 'minimumMacOS:12.0' 'configuration:Release' \
    'signing:ad-hoc; no Developer ID' 'releaseChannel:public-prerelease' \
    "buildTool:$(xcodebuild -version | tr '\n' ' ')"; do
    /usr/bin/plutil -insert "${entry%%:*}" -string "${entry#*:}" "$INFO_PLIST"
done
for entry in 'notarized:false' 'updateFeedEnabled:false' 'physicalChordingVerified:false' \
    'correspondingSourceIncluded:true' "sourceWorktreeDirty:$SOURCE_DIRTY"; do
    /usr/bin/plutil -insert "${entry%%:*}" -bool "${entry#*:}" "$INFO_PLIST"
done
/usr/bin/plutil -convert json -o "${PACKAGE_DIR}/build-info.json" "$INFO_PLIST"
bash "${SCRIPT_DIR}/baram_distribution/verify_app.sh" "${PACKAGE_DIR}/Baram.app" "$VERSION"
/usr/bin/codesign --verify --deep --strict "${PACKAGE_DIR}/Baram.app"
(cd "$PACKAGE_DIR" && find . -type f ! -name SHA256SUMS -print0 | \
    LC_ALL=C sort -z | xargs -0 /usr/bin/shasum -a 256 > "${BUILD_DIR}/SHA256SUMS")
cp "${BUILD_DIR}/SHA256SUMS" "${PACKAGE_DIR}/SHA256SUMS"
(cd "$PACKAGE_DIR" && /usr/bin/shasum -a 256 --status -c SHA256SUMS)
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$PACKAGE_DIR" "$ZIP_PATH"
(cd "$DIST_DIR" && /usr/bin/shasum -a 256 "${PACKAGE_NAME}.zip" > "${PACKAGE_NAME}.zip.sha256")
echo "Unsigned prerelease candidate: $ZIP_PATH"
echo "Checksum: ${ZIP_PATH}.sha256"
