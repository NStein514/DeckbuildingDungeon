# Validation record

## Environment limitation

The machine had no Flutter or Dart executable. The official Flutter `stable` Git checkout succeeded and reports tag `3.47.7`, commit `abaf9c523780a608bd46686fd5e53740a07077f8`. Bootstrapping its Dart SDK failed at the egress proxy:

```text
Downloading Linux x64 Dart SDK from Flutter engine deb287481e3ce9468f3434937ced4240a70539ca...
curl: (56) CONNECT tunnel failed, response 403
```

The required host is `storage.googleapis.com`. The environment configuration draft includes that domain addition. Saving a draft does not apply network changes or prove SDK installation. Review/save the network change in environment settings before retrying; publish the prepared environment after installation and validation succeed.

## Executed checks

- `python3 tool/check_content.py` — passed: 20 distinct cards, 4 enemies, 12-card starting deck, typed effect/status references, valid resource values, artwork manifest coverage, README wording restrictions.
- A Tree-sitter Dart grammar parsed all 17 Dart source/test files without syntax errors. This is a syntax-only check, not Dart type analysis or compilation.
- `bash -n tool/initialize_platforms.sh tool/validate.sh` — passed shell syntax checks.
- `git diff --check` — passed for tracked changes.

## Not executed

- `flutter pub get` and dependency compatibility/resolution; no generated lockfile.
- `dart format lib test`.
- `flutter analyze`.
- `flutter test`: **33 declared tests, zero executed**. There are 30 domain tests and 3 widget tests; no passing result is claimed.
- `flutter build web`, browser launch, full interactive battle, viewport/large-text inspection.
- Native host generation, Android build/device test, iOS build/simulator test.

The formatter, analyzer, tests, and launch remain required before calling Milestone 1 verified. No gameplay bug has been confirmed through execution yet; source review cannot establish their absence.

## Resume validation

Once the SDK host is reachable:

```sh
export PATH="/workspace/toolchains/flutter/bin:$PATH"
export PUB_CACHE=/workspace/.pub-cache
cd /workspace/DeckbuildingDungeon
flutter --version
bash tool/validate.sh
flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8080
```

Inspect a portrait phone layout and a desktop layout. Verify card selection and target selection; energy and health changes; Guard/block; Preparation's discard requirement; enemy intents; end turn; victory; defeat; two-enemy targeting; and reduced-motion settings. A successful HTTP response alone does not validate Flutter interaction. Record actual results here and commit the real dependency lockfile after successful resolution. Test on Android and iOS separately before claiming native support.

The native initializer and validation helper have only been shell-syntax checked. SDK commands inside them are unverified. Final artwork, sound playback, run persistence, rewards, dungeon progression, and fusion are intentionally deferred and are not launch prerequisites for this battle slice.
