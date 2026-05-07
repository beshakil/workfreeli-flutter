# Freeli - Team Collaboration Demo App

A polished Flutter demo app for **Freeli** (https://work.freeli.io) — a team collaboration platform featuring messaging, task boards, file sharing, and user profiles.

## Screenshots & Features

### 🔐 Authentication Flow
- **Splash Screen** — Animated logo with gradient branding
- **Login Screen** — Email & password with pre-filled demo credentials
- **OTP Verification** — 6-digit code verification

### 💬 Messaging
- Channel list with unread badges
- Real-time chat with auto-reply simulation
- File attachment display
- Typing indicator animation
- Self/other message styling

### 📋 Task Board (Kanban)
- Horizontally scrollable columns: To Do → In Progress → Review → Done
- Tagged task cards (Feature, Bug, Design, Infra, Urgent)
- Assignee avatars with overlap stacking
- Due date indicators

### 📁 Files
- Grid view of shared workspace files
- File type icons (PDF, FIG, XLS, DOC, PNG, ZIP, CSV)
- Search bar

### 👤 Profile
- Banner with gradient
- Activity stats (Messages, Tasks, Files)
- Workspace info
- Settings with toggles
- Sign out button

---

## Demo Credentials (pre-filled)

| Field    | Value                  |
|----------|------------------------|
| Email    | fajlehrabbi@gmail.com  |
| Password | a123456                |
| OTP      | 123456                 |

---

## 🚀 Build Instructions

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.0+)
- Android Studio or Xcode (for emulator)
- A connected device or emulator

### Steps to build APK

```bash
# 1. Clone or copy the project folder
cd freeli_app

# 2. Create Flutter project wrapper (if starting fresh)
flutter create --project-name freeli_app .

# 3. Get dependencies
flutter pub get

# 4. Create empty assets folder
mkdir -p assets

# 5. Run on connected device
flutter run

# 6. Build debug APK
flutter build apk --debug

# 7. Build release APK (smaller, optimized)
flutter build apk --release
```

### APK output location
```
build/app/outputs/flutter-apk/app-release.apk
```

---

## Project Structure

```
freeli_app/
├── lib/
│   ├── main.dart                  # App entry point
│   ├── theme/
│   │   └── app_theme.dart         # Colors, typography, decorations
│   ├── models/
│   │   └── data_models.dart       # Data models & sample data
│   └── screens/
│       ├── splash_screen.dart     # Animated splash
│       ├── login_screen.dart      # Email/password login
│       ├── otp_screen.dart        # OTP verification
│       ├── home_screen.dart       # Bottom nav shell
│       ├── chat_screen.dart       # Messaging UI
│       ├── tasks_screen.dart      # Kanban task board
│       ├── files_screen.dart      # File grid
│       └── profile_screen.dart    # User profile
├── pubspec.yaml
├── analysis_options.yaml
└── README.md
```

## Dependencies
- `google_fonts` — DM Sans + Sora typography
- `flutter_animate` — Smooth animations
- `pinput` — OTP input (optional)
- `cupertino_icons` — iOS-style icons
