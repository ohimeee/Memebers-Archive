# Memebers Archive

A Flutter MVP for a private shared group photo gallery. Users sign in, join a closed group, upload compressed images from their phone gallery, and view the shared group timeline sorted newest first.

## Stack

- Flutter for Android and iOS
- Firebase Authentication with Google and email/password
- Cloud Firestore for users, groups, members, and post metadata
- Cloudinary unsigned uploads for image storage

## Firebase Setup

1. Create a Firebase project.
2. Enable Authentication providers: Google and Email/Password.
3. Enable Cloud Firestore.
4. Install FlutterFire CLI if needed:

```bash
dart pub global activate flutterfire_cli
```

5. Configure this app:

```bash
flutterfire configure
```

This generates `lib/firebase_options.dart`, `android/app/google-services.json`, and `ios/Runner/GoogleService-Info.plist`.

6. Deploy rules and indexes:

```bash
firebase deploy --only firestore
```

## Cloudinary Setup

1. Create a free Cloudinary account.
2. Copy your cloud name from the Cloudinary dashboard.
3. Go to Settings > Upload > Upload presets.
4. Create an unsigned upload preset for this app.
5. Run the app with your Cloudinary values:

```bash
flutter run --dart-define=CLOUDINARY_CLOUD_NAME=your_cloud_name --dart-define=CLOUDINARY_UPLOAD_PRESET=your_unsigned_preset
```

## Data Model

Top-level collections:

- `users/{userId}`: display name, email, photo URL, current group
- `groups/{groupId}`: name, invite code, created by, created at
- `groups/{groupId}/members/{userId}`: membership records
- `posts/{postId}`: `imageUrl`, `uploadedAt`, `uploadedBy`, `uploaderName`, `groupId`, `cloudinaryPublicId`

## Run

```bash
flutter pub get
flutter run --dart-define=CLOUDINARY_CLOUD_NAME=your_cloud_name --dart-define=CLOUDINARY_UPLOAD_PRESET=your_unsigned_preset
```

The local Flutter tool was not responding in this environment while scaffolding, so the Firebase config files still need to be generated with `flutterfire configure` before a real device run.
