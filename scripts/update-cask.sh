#!/bin/zsh
# Points the Homebrew cask in tomacco/homebrew-tap at a published release.
# Usage: scripts/update-cask.sh 1.0.0 [path/to/homebrew-tap]
set -euo pipefail
VERSION="${1:?usage: update-cask.sh <version> [tap dir]}"
TAP="${2:-${0:A:h}/../../homebrew-tap}"
URL="https://github.com/tomacco/screen-align/releases/download/v$VERSION/ScreenAlign.zip"

SHA="$(curl -fsSL "$URL" | shasum -a 256 | cut -d' ' -f1)"
mkdir -p "$TAP/Casks"
sed -e "s/__VERSION__/$VERSION/" -e "s/__SHA256__/$SHA/" "${0:A:h}/screen-align.rb.template" > "$TAP/Casks/screen-align.rb"
echo "wrote $TAP/Casks/screen-align.rb ($VERSION, $SHA)"
