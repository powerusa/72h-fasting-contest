# iOS regressions

On macOS with Xcode and Python 3, run from the repository root:

```sh
python3 tests/ios/run.py
```

The runner compiles the real `AppModels.swift` and extracts the production leaderboard listener/ranking methods into a temporary Swift executable. In-memory Firestore transport doubles make timing, cache state, and listener cleanup deterministic without accessing Firebase.

Coverage includes live timer updates without snapshots, 72-hour status transitions, stopped-session exclusion, weekly filtering, cache/server connectivity, stable ties, active-session statistics, interrupted streaks, historic ranks, and isolation of private contest results.

This complements the simulator build and real read-only leaderboard checks. It does not replace an Xcode UI test target or the Firestore emulator rules suite.
