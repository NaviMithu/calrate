
# Milk Calculator (Flutter)

A simple app to track daily milk (1 L, 1/2 L, 1/4 L), store entries locally, set price per liter, and see monthly totals.

## How to build an APK (Android)

1. Install Flutter and Android Studio (or command-line Android SDK).
2. In a terminal:
   ```bash
   flutter --version
   flutter create milk_calculator
   cd milk_calculator
   # Replace the generated pubspec.yaml and lib/main.dart with the ones in this zip.
   # (Copy files to this folder, overwriting existing)
   flutter pub get
   flutter build apk --release
   ```
3. The APK will be at `build/app/outputs/flutter-apk/app-release.apk`. Copy it to your phone and install.

## iOS (optional)
You can run on iOS with Xcode and a Developer account:
```bash
flutter build ipa --release
```

## Features
- Add daily liters with one tap (1 L, 1/2 L, 1/4 L)
- Edit price per liter
- Monthly report: total liters and total cost
- Offline storage using SharedPreferences (key-value)

## Notes
- Pick any date inside the month in Report to view that month.
- To clear a day's entry, open the Add tab for that date and press "Clear this day".
