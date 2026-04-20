# PhytoPi Dashboard Setup Guide

## Prerequisites

Before running the Flutter dashboard, you need to install Flutter SDK:

### 1. Install Flutter SDK

**Windows:**
1. Download Flutter SDK from: https://docs.flutter.dev/get-started/install/windows
2. Extract to `C:\flutter`
3. Add `C:\flutter\bin` to your PATH environment variable
4. Run `flutter doctor` to verify installation

**Alternative - Using Chocolatey:**
```powershell
choco install flutter
```

**Alternative - Using Scoop:**
```powershell
scoop install flutter
```

### 2. Verify Installation

```bash
flutter doctor
```

Make sure all required components are installed (Android SDK, Chrome, etc.)

## Running the Dashboard

### 1. Install Dependencies

```bash
cd dashboard
flutter pub get
```

### 2. Run Development Server

```bash
flutter run -d chrome --web-port 3000
```

### 3. Build for Production

```bash
flutter build web --release
```

## Project Structure

```
dashboard/
├── lib/
│   ├── core/
│   │   ├── config/
│   │   │   ├── app_config.dart
│   │   │   └── supabase_config.dart
│   │   ├── constants/
│   │   └── utils/
│   ├── features/
│   │   ├── auth/
│   │   │   └── providers/
│   │   │       └── auth_provider.dart
│   │   ├── dashboard/
│   │   │   └── screens/
│   │   │       └── dashboard_screen.dart
│   │   ├── devices/
│   │   └── analytics/
│   ├── shared/
│   │   ├── widgets/
│   │   └── services/
│   └── main.dart
├── web/
│   ├── index.html
│   ├── manifest.json
│   └── icons/
├── assets/
│   ├── images/
│   ├── icons/
│   └── fonts/
├── pubspec.yaml
├── analysis_options.yaml
└── README.md
```

## Next Steps

1. **Install Flutter SDK** (if not already installed)
2. **Run `flutter pub get`** to install dependencies
3. **Run `flutter run -d chrome`** to start development server
4. **Configure Supabase** connection in `lib/core/config/app_config.dart`
5. **Start developing** features according to the milestone plan

## Troubleshooting

### Flutter not found
- Make sure Flutter is in your PATH
- Restart your terminal/IDE after installation

### Dependencies issues
- Run `flutter clean` then `flutter pub get`
- Check Flutter version compatibility

### Web development issues
- Make sure Chrome is installed
- Check if web development is enabled: `flutter config --enable-web`
