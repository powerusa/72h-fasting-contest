# Project workflow

The owner requests that verified changes be committed and pushed to GitHub after each completed change. Use the existing branch unless asked otherwise, check for remote updates first, and never force-push or overwrite unrelated work. Report the commit link and any check that could not run.

Keep simulator code signing enabled for Firebase Authentication. Build outside iCloud-synced folders when Finder metadata prevents code signing.

Run `python3 tests/ios/run.py` for the iOS model and leaderboard regressions. Firestore rules changes also require the emulator suite in `tests/firestore` (see its README). Never run destructive test fixtures against production Firebase.

App Store creative artwork belongs in `docs/app-store`; the 3:1 GitHub banner in `docs/images/header.png` is not an upload asset. Run `python3 scripts/validate-app-store-assets.py` after media exports. App Store PNGs must have exact placement/device dimensions and no alpha channel.
