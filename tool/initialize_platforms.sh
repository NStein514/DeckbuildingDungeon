#!/usr/bin/env bash
# Generate official native host projects without overwriting gameplay or docs.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo 'Install Flutter and add flutter/bin to PATH.' >&2; exit 1; }
if [[ -e android || -e ios ]]; then
  echo 'Native host directories already exist; refusing to overwrite them.' >&2
  exit 1
fi
stage_dir=$(mktemp -d)
trap 'rm -rf "$stage_dir"' EXIT
flutter create --platforms=android,ios --project-name=deckbound --org=com.deckbound --no-pub "$stage_dir/deckbound"
cp -R "$stage_dir/deckbound/android" ./android
cp -R "$stage_dir/deckbound/ios" ./ios
printf '%s\n' 'Native hosts generated. Run flutter pub get, then flutter run on your device.'
