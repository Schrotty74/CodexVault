#!/opt/homebrew/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
channel="${1:-dev}"

case "$channel" in
    dev)
        display_name="CodexVault Dev"
        bundle_identifier="com.codexvault.dev"
        marketing_version="0.1.0-dev"
        output_directory="$project_root/Build/dev"
        ;;
    beta)
        display_name="CodexVault Beta"
        bundle_identifier="com.codexvault.beta"
        marketing_version="1.0.0"
        output_directory="$project_root/Build/beta"
        ;;
    final)
        display_name="CodexVault"
        bundle_identifier="com.codexvault"
        marketing_version="0.1.0"
        output_directory="$project_root/Build/final"
        ;;
    *)
        echo "Expected build channel: dev, beta, or final." >&2
        exit 64
        ;;
esac

scratch_directory="$project_root/.build/channels/$channel"
app_bundle="$output_directory/$display_name.app"
template="$project_root/Packaging/Info.plist.template"
entitlements="$project_root/Packaging/CodexVault.entitlements"
icon_bundle="$project_root/Assets/AppIcon/CodexVault.icon"
icon_partial_info="$scratch_directory/CodexVault-icon-info.plist"

swift build --package-path "$project_root" --scratch-path "$scratch_directory" --configuration release
binary_directory="$(swift build --package-path "$project_root" --scratch-path "$scratch_directory" --configuration release --show-bin-path)"
binary_path="$binary_directory/CodexVault"

if [[ ! -x "$binary_path" || ! -f "$template" || ! -f "$entitlements" || ! -d "$icon_bundle" ]]; then
    echo "Build input missing." >&2
    exit 1
fi

rm -rf "$app_bundle"
mkdir -p "$app_bundle/Contents/MacOS" "$app_bundle/Contents/Resources"
cp "$binary_path" "$app_bundle/Contents/MacOS/CodexVault"
cp -R "$project_root/Sources/CodexVaultApp/Resources"/. "$app_bundle/Contents/Resources/"
xcrun actool \
    --compile "$app_bundle/Contents/Resources" \
    --platform macosx \
    --minimum-deployment-target 26.0 \
    --app-icon CodexVault \
    --output-partial-info-plist "$icon_partial_info" \
    "$icon_bundle" >/dev/null

sed -e "s/__BUILD_CHANNEL__/$channel/g" -e "s/__APP_DISPLAY_NAME__/$display_name/g" -e "s/__BUNDLE_IDENTIFIER__/$bundle_identifier/g" -e "s/__MARKETING_VERSION__/$marketing_version/g" "$template" > "$app_bundle/Contents/Info.plist"

if strings "$app_bundle/Contents/MacOS/CodexVault" | grep -Fq "$project_root"; then
    echo "Refusing to build an artifact containing the local project path." >&2
    exit 1
fi

codesign --force --sign - --entitlements "$entitlements" "$app_bundle"
plutil -lint "$app_bundle/Contents/Info.plist" >/dev/null

echo "$app_bundle"
