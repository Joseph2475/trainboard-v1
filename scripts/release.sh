#!/bin/bash
# Builds, signs, notarizes and publishes a TrainBoard release. Installed copies update themselves from it.
# Usage: scripts/release.sh 1.1
set -euo pipefail
VERSION=${1:?"usage: scripts/release.sh <version, e.g. 1.1>"}
cd "$(dirname "$0")/.."
if [[ $(git branch --show-current) != main || -n $(git status --porcelain) ]]; then
  echo "Release from main with everything committed." >&2
  exit 1
fi

BUILD=$(git rev-list --count HEAD)  # only ever goes up, which is how Sparkle tells versions apart
ID="Developer ID Application: Joseph Moylan (69TCYK37VK)"
APP="build/Build/Products/Release/TrainBoard V1.app"
ZIP=build/TrainBoard.zip

xcodegen generate -q
xcodebuild -project TrainBoardV1.xcodeproj -scheme TrainBoardV1 -configuration Release -derivedDataPath build \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD" clean build -quiet

# Sparkle's helpers arrive signed by Sparkle, which notarization rejects: sign them inside out, then reseal the app
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
for item in "$SPARKLE/Versions/B/XPCServices/Installer.xpc" "$SPARKLE/Versions/B/XPCServices/Downloader.xpc" \
            "$SPARKLE/Versions/B/Autoupdate" "$SPARKLE/Versions/B/Updater.app" "$SPARKLE" "$APP"; do
  codesign --force --sign "$ID" --options runtime --timestamp --preserve-metadata=entitlements "$item"
done

ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile trainboard --wait | tee build/notary.log
grep -q "status: Accepted" build/notary.log || { echo "Notarization failed, see build/notary.log" >&2; exit 1; }
xcrun stapler staple "$APP"
ditto -c -k --keepParent "$APP" "$ZIP"  # zip again so the download carries the notarization ticket

# the appcast tells installed copies about this version; Sparkle checks the signature before installing
SIGNATURE=$(build/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update "$ZIP")
cat > appcast.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>TrainBoard</title>
    <item>
      <title>$VERSION</title>
      <pubDate>$(date -R)</pubDate>
      <sparkle:version>$BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
      <enclosure url="https://github.com/Joseph2475/trainboard-v1/releases/download/v$VERSION/TrainBoard.zip" $SIGNATURE type="application/octet-stream"/>
    </item>
  </channel>
</rss>
EOF

# publish the download first, then the appcast that points at it
gh release create "v$VERSION" "$ZIP" --title "TrainBoard $VERSION" --generate-notes
git add appcast.xml
git commit -q -m "Release $VERSION"
git push -q
echo "Released $VERSION (build $BUILD)"
