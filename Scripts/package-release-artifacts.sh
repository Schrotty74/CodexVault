#!/opt/homebrew/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
channel="${1:-}"
artifact_name="${2:-}"

if [[ "$channel" != "beta" && "$channel" != "final" ]]; then
    echo "Expected release channel: beta or final. Dev bundles are never packaged." >&2
    exit 64
fi

if [[ -z "$artifact_name" || "$artifact_name" == */* || "$artifact_name" == .* ]]; then
    echo "Provide a plain artifact base name, for example CodexVault-1.0-Beta-1." >&2
    exit 64
fi

case "$channel" in
    beta)
        display_name="CodexVault Beta"
        volume_name="CodexVault Beta"
        ;;
    final)
        display_name="CodexVault"
        volume_name="CodexVault"
        ;;
esac

app_bundle="$project_root/Build/$channel/$display_name.app"
distribution_directory="$project_root/dist"
zip_path="$distribution_directory/$artifact_name.zip"
dmg_path="$distribution_directory/$artifact_name.dmg"
staging_directory=""
mount_directory=""
attached="false"

cleanup() {
    if [[ "$attached" == "true" && -n "$mount_directory" ]]; then
        hdiutil detach "$mount_directory" -quiet || true
    fi
    if [[ -n "$staging_directory" && "$staging_directory" == "$project_root/.build/release-stage."* ]]; then
        rm -rf "$staging_directory"
    fi
    if [[ -n "$mount_directory" && "$mount_directory" == "$project_root/.build/release-mount."* ]]; then
        rmdir "$mount_directory" 2>/dev/null || true
    fi
}
trap cleanup EXIT

"$project_root/Scripts/build-channel.sh" "$channel" >/dev/null

if [[ ! -d "$app_bundle" ]]; then
    echo "Expected app bundle was not built: $app_bundle" >&2
    exit 1
fi

codesign --verify --deep --strict "$app_bundle"
plutil -lint "$app_bundle/Contents/Info.plist" >/dev/null

if strings "$app_bundle/Contents/MacOS/CodexVault" | grep -Fq "$project_root"; then
    echo "Refusing to package an executable containing the local project path." >&2
    exit 1
fi

if grep -Eaq 'sk-proj-|OPENAI_API_KEY=|github_pat_|ghp_' \
    "$app_bundle/Contents/MacOS/CodexVault" "$app_bundle/Contents/Info.plist"; then
    echo "Refusing to package an artifact containing a credential marker." >&2
    exit 1
fi

mkdir -p "$distribution_directory"
rm -f "$zip_path" "$dmg_path"

(
    cd "$project_root/Build/$channel"
    COPYFILE_DISABLE=1 find "$display_name.app" -print | COPYFILE_DISABLE=1 /usr/bin/zip -q -@ "$zip_path"
)

unzip -t "$zip_path" >/dev/null
if unzip -Z1 "$zip_path" | grep -Eq '(^|/)__MACOSX(/|$)|(^|/)\.DS_Store$|(^|/)\._'; then
    echo "Refusing release ZIP with Finder metadata." >&2
    exit 1
fi

staging_directory="$(mktemp -d "$project_root/.build/release-stage.XXXXXX")"
ditto "$app_bundle" "$staging_directory/$display_name.app"
ln -s /Applications "$staging_directory/Applications"

hdiutil create \
    -volname "$volume_name" \
    -srcfolder "$staging_directory" \
    -format UDZO \
    -ov \
    -imagekey zlib-level=9 \
    "$dmg_path" >/dev/null
hdiutil verify "$dmg_path" >/dev/null

mount_directory="$(mktemp -d "$project_root/.build/release-mount.XXXXXX")"
hdiutil attach "$dmg_path" -nobrowse -readonly -mountpoint "$mount_directory" >/dev/null
attached="true"

if [[ ! -d "$mount_directory/$display_name.app" || ! -L "$mount_directory/Applications" || "$(readlink "$mount_directory/Applications")" != "/Applications" ]]; then
    echo "Release DMG must contain the app and an Applications link." >&2
    exit 1
fi

if [[ "$(find "$mount_directory" -mindepth 1 -maxdepth 1 -print | wc -l | tr -d ' ')" != "2" ]]; then
    echo "Release DMG contains unexpected top-level items." >&2
    exit 1
fi

codesign --verify --deep --strict "$mount_directory/$display_name.app"
if strings "$mount_directory/$display_name.app/Contents/MacOS/CodexVault" | grep -Fq "$project_root"; then
    echo "Refusing DMG containing the local project path." >&2
    exit 1
fi

echo "Release artifacts created:"
echo "  $zip_path"
shasum -a 256 "$zip_path"
echo "  $dmg_path"
shasum -a 256 "$dmg_path"
echo "Verified DMG contains $display_name.app and Applications -> /Applications."
