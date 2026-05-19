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
5. Optional but recommended: deploy the Cloudflare Worker below so deleted photos are permanently removed from Cloudinary.
6. Run the app with your Cloudinary values:

```bash
flutter run --dart-define=CLOUDINARY_CLOUD_NAME=your_cloud_name --dart-define=CLOUDINARY_UPLOAD_PRESET=your_unsigned_preset --dart-define=CLOUDINARY_DELETE_ENDPOINT=https://your-worker-url.workers.dev
```

If `CLOUDINARY_DELETE_ENDPOINT` is not provided, the app can only use Cloudinary's short-lived delete token and then remove the Firestore post.

## Permanent Cloudinary Deletes

Cloudinary API secrets must never be placed in the Flutter app. This project includes a small Cloudflare Worker at `cloudflare/worker` that safely deletes Cloudinary files from a backend.

Setup:

```bash
cd cloudflare/worker
copy wrangler.toml.example wrangler.toml
npm install
npx wrangler login
npx wrangler secret put FIREBASE_PROJECT_ID
npx wrangler secret put FIREBASE_WEB_API_KEY
npx wrangler secret put CLOUDINARY_CLOUD_NAME
npx wrangler secret put CLOUDINARY_API_KEY
npx wrangler secret put CLOUDINARY_API_SECRET
npx wrangler deploy
```

Use these values:

```text
FIREBASE_PROJECT_ID=memebers-87d7b
FIREBASE_WEB_API_KEY=your Firebase web/android API key from lib/firebase_options.dart
CLOUDINARY_CLOUD_NAME=your Cloudinary cloud name
CLOUDINARY_API_KEY=your Cloudinary API key
CLOUDINARY_API_SECRET=your Cloudinary API secret
```

After deploy, copy the Worker URL and run/build Flutter with:

```bash
flutter run --dart-define=CLOUDINARY_CLOUD_NAME=your_cloud_name --dart-define=CLOUDINARY_UPLOAD_PRESET=your_unsigned_preset --dart-define=CLOUDINARY_DELETE_ENDPOINT=https://your-worker-url.workers.dev
```

The delete flow verifies the Firebase user, confirms they uploaded the photo, deletes the Cloudinary asset by `cloudinaryPublicId`, then deletes the Firestore post.

## Data Model

Top-level collections:

- `users/{userId}`: display name, email, photo URL, current group
- `groups/{groupId}`: name, invite code, created by, created at
- `groups/{groupId}/members/{userId}`: membership records
- `posts/{postId}`: `imageUrl`, `uploadedAt`, `uploadedBy`, `uploaderName`, `groupId`, `cloudinaryPublicId`

## Run

```bash
flutter pub get
flutter run --dart-define=CLOUDINARY_CLOUD_NAME=your_cloud_name --dart-define=CLOUDINARY_UPLOAD_PRESET=your_unsigned_preset --dart-define=CLOUDINARY_DELETE_ENDPOINT=https://your-worker-url.workers.dev
```

The local Flutter tool was not responding in this environment while scaffolding, so the Firebase config files still need to be generated with `flutterfire configure` before a real device run.
