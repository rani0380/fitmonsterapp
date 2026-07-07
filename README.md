# Fit Monster

AI pose-recognition fitness game built with Flutter.

## Features

- Squat motion recognition using the camera
- Desert running game with jump detection
- Character selection and target squat settings
- Accumulated workout records
- Daily calorie goal card

## Requirements

- Flutter SDK
- Android SDK
- Android device with camera permission enabled

## Run

```powershell
flutter pub get
flutter run
```

## Build APK

```powershell
flutter build apk --debug
```

The APK is generated at:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

## GitHub Upload Notes

Do not commit generated folders or APK files to the repository.

Excluded by `.gitignore`:

- `.dart_tool/`
- `build/`
- `android/local.properties`
- `android/.gradle/`
- `android/.kotlin/`
- `android/app/.cxx/`
- `*.apk`
- `*.aab`

For QR installation distribution, upload the APK to GitHub Releases and link it from a GitHub Pages install page.
