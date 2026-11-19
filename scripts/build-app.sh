#!/bin/zsh
set -euo pipefail

cd -- "${0:A:h:h}"
build_directory="$PWD/.build"
mkdir -p "$build_directory/module-cache"

# Keep build caches next to the project, including when the shell is sandboxed.
export CLANG_MODULE_CACHE_PATH="$build_directory/module-cache"
swift_options=(
  --manifest-cache local
  --cache-path "$build_directory/cache"
  --config-path "$build_directory/config"
  --security-path "$build_directory/security"
  -c release
  "$@"
)
swift build "${swift_options[@]}" --product Leafbound
binary_directory=$(swift build "${swift_options[@]}" --show-bin-path)

app="$PWD/dist/Leafbound.app"
sparkle_frameworks=("$build_directory"/artifacts/*/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework(N))
if (( ${#sparkle_frameworks} != 1 )); then
  print -u2 'Could not locate the SwiftPM Sparkle framework.'
  exit 1
fi
mkdir -p "$app/Contents/MacOS" "$app/Contents/Frameworks"
rm -rf -- "$app/Contents/Frameworks/Sparkle.framework"
ditto "$sparkle_frameworks[1]" "$app/Contents/Frameworks/Sparkle.framework"
cp "$binary_directory/Leafbound" "$app/Contents/MacOS/Leafbound"
cp scripts/Info.plist "$app/Contents/Info.plist"
plutil -replace CFBundleVersion -string "${LEAFBOUND_BUILD_NUMBER:-1}" "$app/Contents/Info.plist"
codesign --force --sign - "$app"
print -r -- "$app"
