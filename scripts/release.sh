#!/bin/bash
# Builds, signs, notarizes and publishes a TrainBoard release, which the README's Download link always points to.
# Usage: scripts/release.sh 1.1
set -euo pipefail
VERSION=${1:?"usage: scripts/release.sh <version, e.g. 1.1>"}
cd "$(dirname "$0")/.."
if [[ $(git branch --show-current) != main || -n $(git status --porcelain) ]]; then
  echo "Release from main with everything committed." >&2
  exit 1
fi

BUILD=$(git rev-list --count HEAD)  # only ever goes up, so each release has a higher build number
APP="build/Build/Products/Release/TrainBoard V1.app"
ZIP=build/TrainBoard.zip

xcodegen generate -q
xcodebuild -project TrainBoardV1.xcodeproj -scheme TrainBoardV1 -configuration Release -derivedDataPath build \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD" clean build -quiet

ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile trainboard --wait | tee build/notary.log
grep -q "status: Accepted" build/notary.log || { echo "Notarization failed, see build/notary.log" >&2; exit 1; }
xcrun stapler staple "$APP"
ditto -c -k --keepParent "$APP" "$ZIP"  # zip again so the download carries the notarization ticket

gh release create "v$VERSION" "$ZIP" --title "TrainBoard $VERSION" --generate-notes
echo "Released $VERSION (build $BUILD)"
