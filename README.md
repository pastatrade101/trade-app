# Trading Club Signals (Flutter + Firebase MVP)

A production-ready MVP for a community-driven Trading Club Signals app.

## Features
- Email/Password + Google auth
- Onboarding profile with roles and preferences
- Signal creation with strict validation
- Signal feed with filters + pagination
- Community outcome voting and consensus resolution
- Follow system + follower counts
- Admin tips + pinned posts
- Reporting and moderation tools
- Leaderboards and trader ratings
- FCM push notifications (new signals, resolved signals)
- Legal disclaimers in onboarding and settings

## Tech Stack
- Flutter (latest stable)
- State: Riverpod
- Firebase: Auth, Firestore, Storage, Cloud Functions, FCM

## Project Structure
```
lib/
  app/
  core/
    config/
    models/
    repositories/
    services/
    utils/
  features/
    admin/
    auth/
    home/
    leaderboard/
    profile/
    reports/
    tips/
```

## Setup
### 1) Flutter deps
```
flutter pub get
```

### 2) Firebase config
This app uses the FlutterFire CLI style config. Replace placeholder values in `lib/firebase_options.dart` by running:
```
flutterfire configure
```
This generates `google-services.json` and `GoogleService-Info.plist` for Android/iOS.

### 3) Firebase initialization
Ensure Firebase is initialized in `lib/main.dart` (already wired).

### 4) Firestore rules
Deploy rules:
```
firebase deploy --only firestore:rules
```
The rules live at `firestore.rules`.

### 5) Cloud Functions
```
cd functions
npm install
cd ..
firebase deploy --only functions
```

### 6) Run the app
```
flutter run
```

## iOS/Android Notes
- iOS: add `NSPhotoLibraryUsageDescription` in `ios/Runner/Info.plist` for image uploads.

## Firestore Data Model
- users/{uid}
- signals/{signalId}
- signals/{signalId}/votes/{uid}
- tips/{tipId}
- follows/{uid}/following/{traderUid}
- reports/{reportId}

## Notes
- No paid APIs or broker integrations are used.
- FCM tokens are stored under `users/{uid}/tokens/{token}`.
- Consensus thresholds can be adjusted in `lib/core/config/app_constants.dart` and `functions/index.js`.

## Disclaimer
Community-generated content. Not financial advice. No guaranteed profits.
