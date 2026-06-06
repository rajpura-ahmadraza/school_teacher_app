# 🎓 School Teacher App — Setup Guide

## Live API
```
https://laravel-api.emaad-infotech.com/zahab-laravel/public/api/v1
```

## Requirements
- Flutter >= 3.16.0 & Dart >= 3.0.0
- Android Studio / VS Code with Flutter extension
- Android device (API 21+) or emulator

---

## Quick Start

```bash
# 1. Install dependencies
flutter pub get

# 2. Run in debug mode
flutter run

# 3. Build release APK
flutter build apk --release

# 4. Build App Bundle (Play Store)
flutter build appbundle --release
```

---

## Project Structure

```
lib/
├── main.dart
├── core/
│   ├── api/api_client.dart              # Dio + live URL + JWT interceptor
│   ├── providers/auth_provider.dart     # Teacher auth (Riverpod)
│   ├── router/app_router.dart           # GoRouter + auth guard
│   ├── theme/app_theme.dart             # Indigo/Violet Material 3 theme
│   └── widgets/common_widgets.dart      # StatCard, AppAvatar, EmptyState …
└── features/
    ├── auth/
    │   ├── splash_screen.dart           # 1.5s animated indigo splash
    │   └── login_screen.dart            # Card login with animations
    ├── dashboard/
    │   └── dashboard_screen.dart        # Stats, quick actions, leaves, homework
    ├── students/
    │   └── students_screens.dart        # List + Detail screens
    ├── attendance/
    │   └── attendance_screens.dart      # Mark + Report screens
    ├── homework/
    │   └── homework_screens.dart        # List + Form screens
    └── remaining_screens.dart           # Timetable, Leaves, Gallery, Calendar, Bus
```

---

## Screens & Features

| Screen | Features |
|--------|---------|
| **Splash** | 1.5s animated gradient with feature pills |
| **Login** | Gradient card, show/hide password, demo hint |
| **Dashboard** | 4 stat cards, 6 quick actions, pending leaves inline approve/reject, recent homework overdue badges, collapsible app bar |
| **Students** | Search (name/admission/parent), class filter, paginated list, detail screen with full info |
| **Attendance** | Class dropdown, date picker, P/A/L/E per student, mark-all shortcuts, summary strip, save to API |
| **Attendance Report** | Class + month + year filter, per-student progress bar, color-coded % |
| **Homework** | Class filter chips, swipe-to-edit/delete (Slidable), overdue badge, FAB to assign |
| **Homework Form** | Class → Subject cascade, title + description, date picker, create + edit |
| **Timetable** | Class selector, day tabs (Mon–Sat), color-coded slots, teacher + room info |
| **Leaves** | Tabbed pending/approved/rejected, inline approve/reject buttons, reason + date display |
| **Gallery** | Album filter chips, 3-column grid, tap lightbox |
| **Calendar** | Month navigator, event list with color bar, holiday badge |
| **Bus Tracking** | Auto-refresh 15s, speed display, lat/lng, driver info cards |

---

## Login Credentials (Demo)

| Role    | Email                     | Password |
|---------|---------------------------|----------|
| Teacher | teacher1@school.com       | password |
| Teacher | teacher2@school.com       | password |

Only accounts with `role = teacher` can log in through this app.

---

## Fonts (Optional)

Download Inter from [fonts.google.com/specimen/Inter](https://fonts.google.com/specimen/Inter)

Place in `assets/fonts/`:
- `Inter-Regular.ttf`
- `Inter-Medium.ttf`
- `Inter-SemiBold.ttf`
- `Inter-Bold.ttf`

Then uncomment the `fonts:` section in `pubspec.yaml`.

The app works without the font files (falls back to system font).

---

## Build Release APK

```bash
flutter build apk --release --target-platform android-arm64
```

APK location: `build/app/outputs/flutter-apk/app-release.apk`
