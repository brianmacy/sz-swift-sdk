#!/usr/bin/env bash
# Links a Senzing Sz.xcframework into this checkout, so the package builds for
# iOS. The framework is not part of this repository: pass the path of the one
# you have. The link, Frameworks/Sz.xcframework, is git-ignored.
#
#   tools/link-ios-framework.sh /path/to/Sz.xcframework
set -euo pipefail

if [ $# -ne 1 ] || [ ! -f "$1/Info.plist" ]; then
    echo "usage: $0 /path/to/Sz.xcframework" >&2
    exit 64
fi
root="$(cd "$(dirname "$0")/.." && pwd)"
source="$(cd "$1" && pwd)"
mkdir -p "$root/Frameworks"
ln -sfn "$source" "$root/Frameworks/Sz.xcframework"
echo "Linked $root/Frameworks/Sz.xcframework -> $source"
echo "SwiftPM caches the package manifest: run 'swift package reset' here, or in"
echo "Xcode use File > Packages > Reset Package Caches, before the next build."
