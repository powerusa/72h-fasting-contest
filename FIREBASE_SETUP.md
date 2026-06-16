# Firebase Setup for 72H Fasting Contest

Use this checklist before uploading the app to App Store Connect.

## 1. Create the Firebase iOS App

1. Open the Firebase console and create/select the project for 72H Fasting Contest.
2. Add an iOS app with bundle ID:

   ```text
   com.powerusa.72hfastingcontest
   ```

3. Download `GoogleService-Info.plist`.
4. In Xcode, drag `GoogleService-Info.plist` into:

   ```text
   72H Fasting Contest/72H Fasting Contest/Resources/
   ```

5. In the Xcode file dialog, enable:

   ```text
   Copy items if needed
   Add to target: 72H Fasting Contest
   ```

The app calls `FirebaseApp.configure()` automatically when the plist is present in the app bundle.

## 2. Enable Firebase Authentication

1. Firebase Console -> Authentication -> Sign-in method.
2. Enable `Anonymous`.

The app does not ask for email, phone, password, or social login.

## 3. Create Cloud Firestore

1. Firebase Console -> Firestore Database.
2. Create a production database.
3. Choose the closest region for your users.

The app uses these collections:

- `users`
- `fastingSessions`
- `contests`
- `badges`

## 4. Deploy Security Rules

Deploy the rules from:

```text
firestore.rules
```

With Firebase CLI:

```bash
firebase deploy --only firestore:rules
```

Or paste the file into Firebase Console -> Firestore Database -> Rules -> Publish.

## 5. Required Indexes

Firestore may prompt you to create indexes the first time these queries run:

- `fastingSessions`: `userId ==`, `createdAt desc`
- `fastingSessions`: `userId ==`, `status ==`
- `fastingSessions`: `contestId ==`
- `fastingSessions`: `startTime >=`
- `contests`: `participantIds array-contains`
- `contests`: `contestCode ==`
- `badges`: `userId ==`

If Firebase shows an index error in Xcode logs, open the generated Firebase link and create the index.

## 6. App Behavior

- Anonymous auth creates one Firebase user ID per install/device.
- Official fast start time is written with Firebase server timestamps.
- The app writes fasting sessions on start, stop, completion, and badge/contest/profile changes.
- The app does not write every second while the timer runs.
- The leaderboard uses real-time Firestore listeners.
- Local storage remains a cache and convenience layer for faster launch/offline display.

## 7. App Store Privacy URL

Use this privacy policy URL in App Store Connect:

```text
https://github.com/powerusa/72h-fasting-contest/blob/main/PRIVACY_POLICY.md
```
