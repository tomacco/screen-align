#!/bin/zsh
# Builds a universal ScreenAlign.app into build/ and, with --install, copies it to ~/Applications.
set -euo pipefail
cd "${0:A:h}/.."

VERSION="${VERSION:-$(git describe --tags --always 2>/dev/null | sed 's/^v//')}"
APP=build/ScreenAlign.app

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/ScreenAlign"

rm -rf build && mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/ScreenAlign"
sed "s/__VERSION__/$VERSION/g" Resources/Info.plist > "$APP/Contents/Info.plist"
codesign --force --sign "${SIGN_IDENTITY:--}" --options runtime "$APP"
echo "built $APP ($VERSION)"

if [[ "${1:-}" == "--install" ]]; then
  mkdir -p ~/Applications && rm -rf ~/Applications/ScreenAlign.app && cp -R "$APP" ~/Applications/
  echo "installed ~/Applications/ScreenAlign.app"
fi
