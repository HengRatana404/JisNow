# JisNow

JisNow is a Flutter-based electric mobility rental app focused on fast vehicle discovery, booking, customer support, and admin vehicle management.

## Overview

The app includes:

- Google Sign-In and Firebase Authentication
- Vehicle browsing with search and filtering
- Booking flow and booking history
- Customer notifications and support chat
- Admin tools for managing vehicles and bookings
- Google Maps integration for location-based flows

## Tech Stack

- Flutter
- Dart
- Firebase Authentication
- Cloud Firestore
- Cloud Functions
- Firebase Storage
- Google Maps Flutter

## Project Structure

```text
lib/
  data/           Demo and seed data
  models/         Domain models
  screens/        App screens and flows
  services/       Firebase and app repositories
  theme/          Design tokens and theme setup
  widgets/        Reusable UI components

assets/
  branding/       Logos and launcher icon assets
  vehicles/       Vehicle images

functions/        Firebase Cloud Functions
android/          Android project files
ios/              iOS project files
```

## Prerequisites

Before you run the project, make sure these are installed:

- Flutter SDK `3.41.x` or newer
- Dart SDK `3.11.x` or newer
- Android Studio or VS Code with Flutter support
- Git
- Firebase CLI if you want to deploy backend resources

## Clone The Project

```bash
git clone <your-repository-url>
cd JisNow
```

## Install Dependencies

```bash
flutter pub get
```

If you want to work on Cloud Functions too:

```bash
cd functions
npm install
cd ..
```

## Environment Setup

This project already contains Android Firebase configuration files in the repository. Review these files before building for your own environment:

- `android/app/google-services.json`
- `lib/firebase_options.dart`
- `android/app/src/main/res/values/google_maps_api.xml`

If you are connecting the app to a different Firebase project, regenerate the Firebase configuration and update the Google Maps API key.

## Run The App

To check connected devices:

```bash
flutter devices
```

To run in debug mode:

```bash
flutter run
```

To run on a specific device:

```bash
flutter run -d <device-id>
```

## Build APK

Create a release APK with:

```bash
flutter build apk --release
```

The generated APK will be available at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## App Icon

The Android launcher icon is generated from:

```text
assets/branding/jisnow_app_icon.png
```

If you update the logo later, regenerate the launcher icons with:

```bash
dart run flutter_launcher_icons
```

## Useful Commands

Run static analysis:

```bash
flutter analyze
```

Run tests:

```bash
flutter test
```

Clean the build:

```bash
flutter clean
flutter pub get
```

## Notes

- Android is the primary configured platform for Firebase in the current project state.
- Web, Windows, Linux, macOS, and iOS Firebase options are not fully configured in `lib/firebase_options.dart`.
- Review API keys and Firebase settings before publishing a production build.
