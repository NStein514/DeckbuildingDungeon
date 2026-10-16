#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter pub get
# Format first while bootstrapping; use --set-exit-if-changed in CI after formatting.
dart format lib test
flutter analyze
flutter test
flutter build web --no-web-resources-cdn
