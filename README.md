# MaguikayConnect - Flutter app

This app works with your API and PHP web exactly as they are. No API change is needed.

## 1. Put the code in your project

You already created `barangay_app`. Copy these into it (replace what is there):

- the whole `lib/` folder
- `pubspec.yaml`

Then in the VS Code terminal:

```
flutter pub get
flutter run -d chrome
```

## 2. Set the API address (one line)

`lib/core/config.dart`

```dart
static const String baseUrl = 'http://10.84.96.192:5299';
```

Use the IPv4 address of the API laptop (`ipconfig` there) and the port from `launchSettings.json`.
If the hotspot gives the API laptop a new IP, change this line AND the `applicationUrl` in `launchSettings.json`.

Also edit the barangay phone, email and office hours in the same file (they show on the Home screen).

## 3. Real phone (later)

Edit `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest ...>
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.CAMERA"/>

    <application
        android:usesCleartextTraffic="true"
        ... >
```

(`usesCleartextTraffic` is needed because the API runs on plain `http`.)

Then plug in the phone (USB debugging on), run `flutter devices`, then `flutter run`.
The phone must be on the same hotspot as the API laptop.

## 4. Optional logo

Put the barangay seal at `assets/logo.png` and uncomment the `assets:` lines in `pubspec.yaml`.

## What each screen uses from your API

| Screen | Endpoint |
|---|---|
| Login | `POST /api/Login` |
| Register (2 steps) | `GET /api/Register/puroks`, `POST /api/Register` |
| Home | `GET /api/Announcement`, `GET /api/Profile` |
| Community feed | `GET /api/Announcement` + `GET /api/Complaint` |
| Report concern / post | `POST /api/Complaint` |
| My requests | `GET /api/Complaint` (only your own are shown) |
| Notifications | `GET /api/Notification`, `POST read/{id}`, `POST read-all` |
| Profile, photo, edit info | `GET/PUT /api/Profile`, `POST /api/Profile/photo` |
| Settings | `POST /api/Profile/password`, `DELETE /api/Profile` |
| Help & FAQ | `GET /api/ChatbotFaq` |

## Where the app differs from the Figma (because the API has no support yet)

- Register asks for username, ID type, ID front, ID back and a live selfie (the API requires these). Contact number is added later under Profile > Personal Information.
- Post category, location, likes and comments are not shown. The API does not store them.
- Make Reservation / Bookings are left out. Home has a Community Feed button in its place.
- The login token lasts 60 minutes. When it expires the app returns to the login screen with a message.
