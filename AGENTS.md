# Project workflow

The owner requests that verified changes be committed and pushed to GitHub after each completed change. Use the existing branch unless asked otherwise, check for remote updates first, and never force-push or overwrite unrelated work. Report the commit link and any check that could not run.

Keep simulator code signing enabled for Firebase Authentication. Build outside iCloud-synced folders when Finder metadata prevents code signing.

Run `python3 tests/ios/run.py` for the iOS model and leaderboard regressions. Firestore rules changes also require the emulator suite in `tests/firestore` (see its README). Never run destructive test fixtures against production Firebase.
