# Firestore security regressions

These tests use a local emulator and the `demo-fasting-contest` project. They refuse to run without `FIRESTORE_EMULATOR_HOST`; no production data is used.

Requirements: Node.js 22+, Java 21+, and pnpm. From this directory:

```sh
pnpm install --frozen-lockfile --ignore-scripts
pnpm run emulator-test
```

The suite checks authenticated leaderboard reads, ownership, backdated/future starts, early completion, locked sessions, profile privacy, contest membership, and safe self-joins/leaves. Firebase CLI authentication is not required for this demo project.

Deploying `firestore.rules` to the real project is a separate authenticated operation:

```sh
pnpm exec firebase login
pnpm exec firebase deploy --only firestore:rules --project h-fasting-contest --config ../../firebase.json
```
