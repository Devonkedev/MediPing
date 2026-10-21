# MediPing

A cross-platform Flutter app scaffolding for the Remedi project. Includes Firebase auth, Firestore, Storage, local Hive reminders, Google Sheets integration, and basic screens.

## Setup

1. Create a Firebase project and add Android & iOS apps. Download `google-services.json` (android/app/) and `GoogleService-Info.plist` (ios/Runner/).
2. Enable Firebase Authentication (Google, Apple).
3. Create Firestore database and Storage bucket.
4. Publish your Google Sheet and use the CSV/published URL for health data (replace in `lib/constants.dart`).
5. Run:

```bash
flutter pub get
flutter run
```

## Notes

- Replace placeholder Firebase files.
- The project uses Hive for local reminders and Flutter Local Notifications for scheduled reminders.
- For production, secure Firestore rules and review platform-specific signing configs.
