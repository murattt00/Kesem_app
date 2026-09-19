# 👛 Kesem — Privacy-First Personal Finance & Expense Tracker (Flutter & Drift)

[![Flutter](https://img.shields.io/badge/Framework-Flutter%203.x-02569B.svg?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Language-Dart%203.x-0175C2.svg?logo=dart&logoColor=white)](https://dart.dev/)
[![Riverpod](https://img.shields.io/badge/State-Riverpod%203-blueviolet.svg)](https://riverpod.dev/)
[![Database](<https://img.shields.io/badge/Database-Drift%20(SQLite)-003B57.svg?logo=sqlite&logoColor=white>)](https://drift.simonbinder.eu/)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-green.svg)]()
[![Privacy](https://img.shields.io/badge/Privacy-100%25%20Offline%20%2F%20Zero%20Tracking-success.svg)]()

Kesem is a modern, privacy-focused personal finance and expense tracking mobile application built with **Flutter, Riverpod 3, and Drift (SQLite)**. Engineered with a strict **offline-first philosophy**, it ensures that user financial data never leaves the physical device. It features zero-float monetary arithmetic, idempotent recurring transaction scheduling, interactive category visualizers, and comprehensive JSON/CSV data portability.

---

## 📌 Philosophy & Engineering Highlights

Unlike mainstream budgeting applications that monetize or transmit sensitive personal financial records:

- **🔒 100% Offline Architecture:** Zero external cloud servers, zero analytics SDKs, and no user registration required.
- **💰 Zero-Float Financial Precision:** All monetary amounts are modeled internally as 64-bit integers (`int` in kuruş / cents). This completely eliminates IEEE-754 floating-point rounding errors common in financial calculations.
- **🔄 Idempotent Recurring Engine:** Recurring transactions (salaries, subscriptions, rent) are generated deterministically using a `lastGeneratedDate` cursor. Even if the user does not open the app for months, past intervals are caught up accurately without recreating transactions the user intentionally deleted.
- **🛡️ Non-Destructive Category Archival:** Categories are never hard-deleted from the database; they are archived with soft-deletion flags, ensuring historical transaction logs and past monthly reports remain intact.

---

## ✨ Key Features

### ⚡ 1. Rapid Transaction Logging & Presets

- **Ergonomic Keypad:** Large touch targets and instant category selection designed for single-hand mobile use.
- **One-Tap Quick Presets:** Fast entry for repetitive daily expenses (e.g., Coffee, Lunch, Public Transit).
- **Search & Filter:** Instant search by category, date range, payment type, or description note.

### 📊 2. Visual Analytics & Budgeting

- **Interactive Donut Chart:** Categorical spending distribution powered by `fl_chart`.
- **Month-over-Month (MoM) Trends:** Visual income vs. expense bars comparing spending against the previous month.
- **Savings Rate KPI:** Real-time financial efficiency indicator (e.g., _"Tasarruf %45"_).
- **Category Budget Warnings:** Configurable monthly limits per category with proactive overspend alerts.

### 🔁 3. Recurring Schedules & Reminders

- Automated recurring schedules (Monthly, Weekly, Bi-weekly).
- **Local Notifications:** Scheduled local reminders for upcoming bills, rent due dates, and end-of-month summaries via `flutter_local_notifications` and `timezone`.

### 💾 4. Complete Data Sovereignty (Backup & Restore)

- **JSON Full Backup:** Export and import complete application state (transactions, categories, recurring templates, and settings).
- **CSV Spreadsheet Export:** Export clean tabular data directly into Excel or Google Sheets.

### 🎨 5. UI/UX & Localization

- **Material You (MD3) Design:** Ergonomic layouts with dynamic theme adaptations.
- **High-Contrast Dark Mode:** Dedicated AMOLED dark palette for battery efficiency and night usability.
- **Full Turkish & Lira Localization:** Formatted with `intl` (`tr_TR`) for localized currency (`₺`) and date standards.

---

## 🏗️ Architecture & State Management

Kesem follows a clean, reactive architecture powered by **Flutter Riverpod 3**:

```
                       User Interactions (UI Layer)
                                     │
                                     ▼
                   Riverpod State Notifiers & Providers
                   (Reactive State Management & ViewModels)
                                     │
               ┌─────────────────────┴─────────────────────┐
               ▼                                           ▼
       Domain Services                              Local Repositories
  ├── Idempotent Recurring Engine              (Drift / SQLite Database)
  ├── Category Archival Logic                               │
  └── JSON/CSV Exporter & Importer                          ▼
                                                    Device SQLite File
```

---

## 🛠️ Technology Stack

| Component                     | Package / Tool                                    | Purpose                                       |
| ----------------------------- | ------------------------------------------------- | --------------------------------------------- |
| **Framework & Language**      | Flutter 3.x, Dart 3.x                             | Cross-platform client framework               |
| **State Management**          | `flutter_riverpod: ^3.3.2`                        | Declarative, compile-safe state management    |
| **Local Database**            | `drift: ^2.34.2`, `drift_flutter`                 | Type-safe SQLite abstraction & query builder  |
| **Code Generation**           | `build_runner`, `drift_dev`                       | Compile-time schema generation                |
| **Data Visualization**        | `fl_chart: ^1.2.0`                                | High-performance interactive financial charts |
| **Localization & Formatting** | `intl: 0.20.2`                                    | Turkish Lira currency and calendar formatting |
| **Local Notifications**       | `flutter_local_notifications`, `timezone`         | Device-side scheduled reminders               |
| **File Sharing & Storage**    | `share_plus`, `file_selector`, `path_provider`    | JSON/CSV export and import file dialogs       |
| **Branding & Assets**         | `flutter_launcher_icons`, `flutter_native_splash` | Adaptive app icons & native splash screen     |

---

## 📂 Project Structure

```
harcama_takip_app/
├── lib/
│   ├── core/                # Constants, theme colors, monetary utils (kuruş conversion)
│   ├── data/                # Drift database definition, tables, DAOs, and migrations
│   ├── domain/              # Models, business logic, recurring transaction engine
│   ├── presentation/        # UI Screens (Home, Analytics, Recurring, Settings, QuickAdd)
│   └── main.dart            # Application entrypoint & ProviderScope initialization
├── assets/
│   └── icon/                # Vector & high-res icons (foreground/background)
├── android/                 # Android native shell & build configurations
├── ios/                     # iOS native configuration
├── web/                     # Web deployment support
├── test/                    # Unit tests for monetary math, drift DAOs, and recurring logic
├── pubspec.yaml             # Project dependencies and asset definitions
└── README.md                # Project documentation
```

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (v3.19+ recommended, Dart SDK ^3.12.2)
- Android Studio / VS Code with Flutter extensions
- Android device or emulator (minSdk 21+)

### 1. Clone the Repository

```bash
git clone https://github.com/murattt00/Kesem_app.git
cd Kesem_app
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Generate Database Code (Drift)

Whenever database tables or queries are updated, run the code generator:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 4. Run the Application

```bash
# Run on connected device or emulator:
flutter run

# Or preview in Chrome:
flutter run -d chrome
```

### 5. Running Automated Tests & Static Analysis

```bash
flutter test
flutter analyze
```

---

## 📦 Production Release Build

When compiling a release APK or App Bundle for Android:

```bash
# Note: --no-tree-shake-icons is required because dynamic IconData is used for custom categories:
flutter build apk --release --no-tree-shake-icons
```

The compiled release APK will be generated at `build/app/outputs/flutter-apk/app-release.apk`.

---
