# Verification — October 17, 2026

## Completed checks

- Signed Debug iOS simulator build with Firebase dependencies.
- Swift regression runner (`python3 tests/ios/run.py`) using production model and ranking/listener code with a simulated Firestore transport.
- 15 Firestore security regressions against the local emulator, with no production fixtures or writes.
- Firebase anonymous authentication and live global leaderboard reads on iPhone 18 Pro.
- Global/This Week switching against the live backend; the current active iPhone session is visible in the global list.
- Actual simulator screen captures on iPhone, iPad, and Duo (including Duo fold/orientation changes).
- Source review of iOS state, persistence, profiles, notifications, contest actions, and the Android repository, models, view model and screens.

## Fixes included

- Do not create a remote profile with a fabricated UID after authentication fails.
- Keep simulator signing enabled so Firebase can access the keychain.
- Recalculate live ranking times from cached snapshots, with stable tie-breaking; invalidate timers and ignore obsolete listener callbacks.
- Keep weekly results separate from global ranking/statistics; use contest-specific listeners for private contest results.
- Count active-session best times, interrupted streaks and historic ranks correctly.
- Confirm completion with the backend before moving a session into completed history and awarding the 72-hour badge. Retain and retry failed completion attempts.
- Prevent overlapping session mutations on one client; clamp negative elapsed times and move the challenge clock above individual tabs.
- Require server timestamps at session creation; reject forged pre-completed sessions and invalid contest membership. Restrict contest joins to the authenticated user.
- Correct visible “Leaderboard” spelling, prevent wrapped status badges, and replace placeholder support links.

## Limits and deployment

- The changed Firestore rules still need authenticated deployment to `h-fasting-contest`. Updating GitHub alone does not deploy them.
- Android was reviewed as source. This Mac has no Android SDK or Android emulator, so an APK/device check was not performed.
- A real 72-hour completion was not awaited. Time boundary logic and security enforcement were tested using local fixtures.
- “One active session” is checked in clients. Strict atomic enforcement across concurrent devices sharing one Firebase UID needs a server-side lock/transaction design.
- Private contest documents remain readable by authenticated app users to support the current invite-code lookup. Their session results also participate in the disclosed global leaderboard; these contests are not confidential workspaces.
- The leaderboard currently reads the complete session collection. Server-side aggregation/pagination is still needed if the dataset grows substantially.
