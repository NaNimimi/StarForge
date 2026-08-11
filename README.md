<div align="center">

# ★ StarForge EDU

### A beautifully focused command center for modern education teams

Manage students, branches, classrooms, people, finance, communication, and quality control from one polished Flutter experience.

<p>
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white">
  <img alt="Dart" src="https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white">
  <img alt="Material 3" src="https://img.shields.io/badge/Material-3-6750A4?style=for-the-badge&logo=materialdesign&logoColor=white">
  <img alt="Platforms" src="https://img.shields.io/badge/Android_·_iOS-Ready-4F7B3B?style=for-the-badge">
</p>

<p>
  <img alt="Uzbek" src="https://img.shields.io/badge/UZ-Uzbek-4F7B3B?style=flat-square">
  <img alt="Russian" src="https://img.shields.io/badge/RU-Russian-4F7B3B?style=flat-square">
  <img alt="English" src="https://img.shields.io/badge/EN-English-4F7B3B?style=flat-square">
  <img alt="Version" src="https://img.shields.io/badge/version-1.5.7-C68423?style=flat-square">
</p>

</div>

---

## The product

StarForge EDU turns the daily complexity of an education center into a calm, clear, and actionable workspace. Every role receives the tools, navigation, and information it needs—without unnecessary visual noise.

The interface is designed for quick decisions on a phone and comfortable analysis on a larger screen. Compact cards, meaningful color, responsive layouts, thoughtful empty states, and clear drill-down pages keep the experience consistent from overview to detail.

## Three focused workspaces

| Workspace | Designed for | Core focus |
| :--- | :--- | :--- |
| **CEO** | Owners and executive teams | Performance, branch comparison, revenue, growth, people, and strategic visibility |
| **Manager** | Branch and operations managers | Students, groups, attendance, payments, approvals, schedules, and communication |
| **Audit** | Audit and quality teams | Risk signals, financial checks, immutable activity history, cases, and compliance |

Each workspace has its own permission-aware navigation, dashboard priorities, actions, and visual context.

## What is inside

### Executive overview

- Role-specific dashboards with operational KPIs
- Interactive revenue, attendance, and performance charts
- Six- and twelve-month reporting views
- Branch ranking and side-by-side branch comparison
- Date-range filtering across analytical screens
- Search, quick actions, favorites, and recent destinations

### Students and learning

- Compact student directory with advanced filters
- Rich student profiles with identity, contacts, learning status, debt, and attendance
- Interactive attendance trend and progress visualizations
- Student Flow views for active, new, and former students
- Group workspaces with students, teachers, schedules, exams, notes, and history
- Attendance and payment history at group level

### People and organization

- Dedicated teacher profiles and assigned groups
- Student lists inside every teacher group
- Parent cards with child, teacher, enrollment date, and last-call information
- Detailed parent and child views
- HR workspace with employee details and salary calculations
- Department management with branch, lead, owner, status, description, and creation date

### Finance and control

- Payment workspace with date filters and interactive breakdown charts
- Complete payment detail pages
- Revenue and expense reporting
- Payroll preparation and employee calculation views
- Debt visibility for students and groups
- Export-ready report flows

### Communication

- Telegram-inspired conversations
- Text, emoji, image, video, document, file, camera, and gallery attachments
- Attachment previews and upload progress states
- Voice-message recording with timer, waveform, cancel gesture, and lock gesture
- Voice-message playback after sending
- Message reactions and long-press interaction
- User profile navigation directly from a conversation

### Audit and quality

- Risk and anomaly signals with severity levels
- Audit cases, ownership, status, and history
- Financial review workspace
- Card fairness and survey integrity views
- Activity journal and AI-usage monitoring
- Clear empty, restricted, warning, and recovery states

## Design language

StarForge EDU uses a custom Material 3 design system built around clarity, density, and warmth.

| Element | Approach |
| :--- | :--- |
| **Color** | Calm olive surfaces, warm neutral backgrounds, and semantic success, warning, and danger tones |
| **Typography** | Manrope for interface text, Instrument Serif for editorial moments, and JetBrains Mono for numbers |
| **Surfaces** | Compact cards, subtle borders, restrained elevation, and consistent corner radii |
| **Motion** | Soft page transitions, staggered reveals, chart interaction, and responsive press feedback |
| **Navigation** | Desktop sidebar and elegant mobile drawer with role-specific destinations |
| **Responsiveness** | Adaptive grids that naturally move between one, two, three, and four columns |
| **Accessibility** | Clear hierarchy, generous touch targets, semantic actions, readable contrast, and text scaling |

## Experience map

```text
Dashboard
├── Branches ── Comparison ── Reports
├── Students ── Student Profile ── Attendance / Payments
├── Groups ──── Students / Exams / History / Analytics
├── Teachers ── Groups ────────── Students
├── Parents ─── Child Details
├── HR ──────── Employee Profile ─ Payroll
├── Finance ─── Payment Details ── Revenue / Debt
├── Messages ── Chat ───────────── Attachments / Voice / Reactions
└── Audit ───── Signals ────────── Cases / Logs / Reviews
```

## Project structure

```text
lib/
├── main.dart                 App entry, localization, and workspace lifecycle
├── console.dart              Responsive shell and role-aware navigation
├── screens.dart              Main product screens and rich detail experiences
├── web_mobile_pages.dart     Adaptive operational workspaces
├── pages.dart                Extended administration and audit modules
├── reference_ui.dart         Material 3 component library and layout primitives
├── widgets.dart              Shared controls, charts, avatars, and visualizations
├── theme.dart                Colors, typography, spacing, and theme tokens
├── i18n.dart                 Uzbek, Russian, and English interface copy
├── settings.dart             Appearance, language, density, and preferences
├── store.dart                Shared product state and cross-screen workflows
├── data.dart                 Product models and presentation helpers
└── productivity_hub.dart     Search, favorites, recent actions, and shortcuts

assets/
└── avatars/                  Role identity artwork

fonts/
├── Manrope.ttf
├── InstrumentSerif-Regular.ttf
├── InstrumentSerif-Italic.ttf
└── JetBrainsMono.ttf
```

## Getting started

### Requirements

- Flutter SDK compatible with the version declared in `pubspec.yaml`
- Dart SDK `^3.12.1`
- Android Studio or Android SDK for Android builds
- Firefox or another modern browser for the Web experience

### Install dependencies

```bash
flutter pub get
```

### Run on Android

```bash
flutter devices
flutter run -d <device-id>
```

### Live API and Firebase push

The API origin and Firebase client identifiers are supplied at build time, so
credentials and environment-specific values are never committed to source.

```bash
flutter build apk --release \
  --dart-define="STARFORGE_API_BASE_URL=https://your-tenant.example" \
  --dart-define="STARFORGE_FIREBASE_PROJECT_ID=your-project" \
  --dart-define="STARFORGE_FIREBASE_MESSAGING_SENDER_ID=123456789" \
  --dart-define="STARFORGE_FIREBASE_ANDROID_API_KEY=your-android-api-key" \
  --dart-define="STARFORGE_FIREBASE_ANDROID_APP_ID=1:123456789:android:app-id" \
  --dart-define="STARFORGE_FIREBASE_STORAGE_BUCKET=your-project.firebasestorage.app"
```

Native `android/app/google-services.json` and
`ios/Runner/GoogleService-Info.plist` are also supported. After login the app
registers its stable device ID and FCM token through
`POST /api/v1/users/devices/`, refreshes rotated tokens, displays foreground
messages, handles background/terminated delivery, and opens chats for payloads
containing `thread_id`.

### Run on Web

```bash
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8081
```

Then open `http://127.0.0.1:8081` in your browser.

## Quality checks

Format and analyze the project:

```bash
dart format lib test
flutter analyze
```

Run the test suite:

```bash
flutter test
```

The tests cover responsive navigation, role boundaries, interactive charts, filters, group and student workflows, chat behavior, payments, payroll, localization, and visual regression safeguards.

## Release builds

### Android APK

```bash
flutter build apk --release
```

Output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

### Web

```bash
flutter build web --release
```

Output:

```text
build/web/
```

## Product principles

1. **Show the next useful action.** Every card should help a person decide or move forward.
2. **Keep information dense, not crowded.** More useful content fits on screen without sacrificing readability.
3. **Respect role boundaries.** Navigation and actions reflect the responsibilities of each workspace.
4. **Prefer meaningful detail.** A tap opens a complete profile, record, history, or workflow—not a dead notification.
5. **Stay consistent everywhere.** Spacing, typography, motion, status colors, and interaction patterns belong to one system.
6. **Design for real operations.** Filters, date ranges, reset actions, exports, histories, and drill-downs are first-class features.

---

<div align="center">

### Built with Flutter. Designed for education teams that value clarity.

**StarForge EDU** · One workspace for every important decision.

</div>
