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
mkdir -p "$app/Contents/MacOS"
cp "$binary_directory/Leafbound" "$app/Contents/MacOS/Leafbound"
cp scripts/Info.plist "$app/Contents/Info.plist"
codesign --force --sign - "$app"
print -r -- "$app"
