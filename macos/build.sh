#!/bin/zsh
set -e
cd "$(dirname "$0")"

APP_NAME="KosmoRadio"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
FRAMEWORKS_DIR="${CONTENTS_DIR}/Frameworks"

# Version: APP_VERSION env var (set by the release workflow from the git tag),
# otherwise the VERSION file. The build number is derived from it
# (1.3.0 -> 10300) so Sparkle can always compare versions.
APP_VERSION="${APP_VERSION:-$(cat VERSION)}"
APP_VERSION="${APP_VERSION#v}"
IFS=. read -r V_MAJOR V_MINOR V_PATCH <<< "${APP_VERSION}"
APP_BUILD=$(( ${V_MAJOR:-0} * 10000 + ${V_MINOR:-0} * 100 + ${V_PATCH:-0} ))

# Sparkle (auto-updates): downloaded once into vendor/, checksum-pinned.
SPARKLE_VERSION="2.10.1"
SPARKLE_SHA256="1a856d2a9edb8e628de88121d7be04cf0e2167f8641650b78fca00b14244cf27"
SPARKLE_DIR="vendor/Sparkle"
SPARKLE_FEED_URL="https://github.com/marcellomarch/kosmo-radio-player/releases/latest/download/appcast.xml"
SPARKLE_PUBLIC_KEY="nyLmUIYtRLBm8aqyE9pUy7V2wbBnA4hj15CLK2XWFR8="

if [ ! -d "${SPARKLE_DIR}/Sparkle.framework" ] || [ "$(cat "${SPARKLE_DIR}/.version" 2>/dev/null)" != "${SPARKLE_VERSION}" ]; then
    echo "⬇️  Downloading Sparkle ${SPARKLE_VERSION}..."
    rm -rf "${SPARKLE_DIR}" && mkdir -p "${SPARKLE_DIR}"
    SPARKLE_TARBALL="vendor/Sparkle-${SPARKLE_VERSION}.tar.xz"
    curl -sSfL -o "${SPARKLE_TARBALL}" "https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"
    echo "${SPARKLE_SHA256}  ${SPARKLE_TARBALL}" | shasum -a 256 -c - >/dev/null
    tar -xf "${SPARKLE_TARBALL}" -C "${SPARKLE_DIR}"
    rm -f "${SPARKLE_TARBALL}"
    echo "${SPARKLE_VERSION}" > "${SPARKLE_DIR}/.version"
fi

echo "🔨 Creating bundle ${APP_BUNDLE} ${APP_VERSION} (${APP_BUILD})..."
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

# Create Info.plist with ATS enabled for HTTP radio streams
cat > "${CONTENTS_DIR}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>it</string>
    </array>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>io.github.marcellomarch.KosmoRadio</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>Kosmo Radio</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${APP_BUILD}</string>
    <key>SUFeedURL</key>
    <string>${SPARKLE_FEED_URL}</string>
    <key>SUPublicEDKey</key>
    <string>${SPARKLE_PUBLIC_KEY}</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
    <key>SUScheduledCheckInterval</key>
    <integer>86400</integer>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
</dict>
</plist>
EOF

if [ ! -f "${RESOURCES_DIR}/AppIcon.icns" ]; then
echo "🎨 Generating macOS icon..."
ICONSET_DIR="/tmp/KosmoRadio.iconset"
rm -rf "${ICONSET_DIR}"
mkdir -p "${ICONSET_DIR}"

swift - <<'SWIFT_ICON'
import AppKit

let iconsetPath = "/tmp/KosmoRadio.iconset"
let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

for (px, filename) in sizes {
    let size = NSSize(width: px, height: px)
    let img = NSImage(size: size)
    img.lockFocus()

    let rect = NSRect(origin: .zero, size: size)
    let inset = CGFloat(px) * 0.08
    let cardRect = rect.insetBy(dx: inset, dy: inset)
    let radius = CGFloat(px) * 0.22

    let path = NSBezierPath(roundedRect: cardRect, xRadius: radius, yRadius: radius)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.08, green: 0.34, blue: 0.78, alpha: 1.0),
        NSColor(calibratedRed: 0.14, green: 0.16, blue: 0.36, alpha: 1.0)
    ])!
    gradient.draw(in: path, angle: -45)

    // Gold accent wave ring
    let center = NSPoint(x: size.width / 2, y: size.height / 2)
    for rFactor in [0.28, 0.36] {
        let r = CGFloat(px) * CGFloat(rFactor)
        let ringRect = NSRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        let ring = NSBezierPath(ovalIn: ringRect)
        ring.lineWidth = max(1.5, CGFloat(px) * 0.018)
        NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.18, alpha: 0.45).setStroke()
        ring.stroke()
    }

    if let symbol = NSImage(systemSymbolName: "antenna.radiowaves.left.and.right", accessibilityDescription: nil) {
        let config = NSImage.SymbolConfiguration(pointSize: CGFloat(px) * 0.42, weight: .bold)
            .applying(.init(paletteColors: [.white]))
        if let configured = symbol.withSymbolConfiguration(config) {
            let symSize = configured.size
            let drawRect = NSRect(
                x: (size.width - symSize.width) / 2,
                y: (size.height - symSize.height) / 2,
                width: symSize.width,
                height: symSize.height
            )
            configured.draw(in: drawRect)
        }
    }

    img.unlockFocus()

    if let tiff = img.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(filename)"))
    }
}
SWIFT_ICON

iconutil -c icns "${ICONSET_DIR}" -o "${RESOURCES_DIR}/AppIcon.icns" || true
rm -rf "${ICONSET_DIR}"
fi

echo "⚡ Compiling Swift sources (Universal Binary: Apple Silicon + Intel, macOS 14.0+)..."
swiftc \
    -O \
    -target arm64-apple-macos14.0 \
    -F "${SPARKLE_DIR}" \
    -framework Sparkle \
    -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
    -framework SwiftUI \
    -framework AppKit \
    -framework AVFoundation \
    -framework MediaPlayer \
    Sources/*.swift \
    -o "/tmp/${APP_NAME}_arm64"

swiftc \
    -O \
    -target x86_64-apple-macos14.0 \
    -F "${SPARKLE_DIR}" \
    -framework Sparkle \
    -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
    -framework SwiftUI \
    -framework AppKit \
    -framework AVFoundation \
    -framework MediaPlayer \
    Sources/*.swift \
    -o "/tmp/${APP_NAME}_x86_64"

lipo -create -output "${MACOS_DIR}/${APP_NAME}" "/tmp/${APP_NAME}_arm64" "/tmp/${APP_NAME}_x86_64"
rm -f "/tmp/${APP_NAME}_arm64" "/tmp/${APP_NAME}_x86_64"

echo "🧩 Embedding Sparkle.framework..."
rm -rf "${FRAMEWORKS_DIR}" && mkdir -p "${FRAMEWORKS_DIR}"
ditto "${SPARKLE_DIR}/Sparkle.framework" "${FRAMEWORKS_DIR}/Sparkle.framework"

xattr -cr "${APP_BUNDLE}" 2>/dev/null || true
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "📦 Creating distribution packages (.zip and .dmg)..."
rm -f "${APP_NAME}-Mac.zip" "${APP_NAME}-Installer.dmg"
ditto -c -k --sequesterRsrc --keepParent "${APP_BUNDLE}" "${APP_NAME}-Mac.zip"

DMG_STAGE="/tmp/${APP_NAME}_dmg_stage"
rm -rf "${DMG_STAGE}"
mkdir -p "${DMG_STAGE}"
cp -R "${APP_BUNDLE}" "${DMG_STAGE}/"
ln -s /Applications "${DMG_STAGE}/Applications"

cat > "${DMG_STAGE}/🔓 Unlock and Open (First Launch).command" <<'UNLOCK_SCRIPT'
#!/bin/zsh
DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -d "/Applications/KosmoRadio.app" ]; then
    xattr -cr "/Applications/KosmoRadio.app" 2>/dev/null || true
    open "/Applications/KosmoRadio.app"
elif [ -d "${DIR}/KosmoRadio.app" ]; then
    cp -R "${DIR}/KosmoRadio.app" /Applications/ 2>/dev/null || true
    xattr -cr "/Applications/KosmoRadio.app" 2>/dev/null || true
    open "/Applications/KosmoRadio.app"
fi
UNLOCK_SCRIPT
chmod +x "${DMG_STAGE}/🔓 Unlock and Open (First Launch).command"

hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_STAGE}" -ov -format UDZO "${APP_NAME}-Installer.dmg" >/dev/null
rm -rf "${DMG_STAGE}"

echo "✅ Build complete: ${APP_BUNDLE}, ${APP_NAME}-Mac.zip and ${APP_NAME}-Installer.dmg"
