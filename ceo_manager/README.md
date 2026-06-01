# StarForge EDU — CEO / Manager Console

A Flutter mobile app for managing **education centers** (tutoring centers, language
schools, exam-prep centers). It ports the StarForge EDU design system into a native
Flutter app with three role consoles:

| Console     | Who                  | Scope             | Tabs                                |
|-------------|----------------------|-------------------|-------------------------------------|
| **CEO**     | Sardor Rashidov      | All branches      | Panel · O‘quvchi · Xabar · AI · Profil |
| **Manager** | Dilnoza Yo‘ldosheva  | Yunusobod branch  | Panel · O‘quvchi · Xabar · Tasdiq · Profil |
| **Audit**   | Jamshid Qodirov      | Oversight (dark)  | Panel · Signal · Xabar · Holat · Profil |

Pick a console on launch; switch any time from **Profil → Rolni almashtirish**.

## Screens

- **Panel (Dashboard)** — KPI tiles with sparklines, 12-month revenue area chart,
  AI strategic insight, branch ranking (CEO) / approvals preview (Manager) /
  recent flags (Audit), and an attendance-health donut.
- **O‘quvchilar (Students)** — roster with attendance %, payment status pills, debt.
- **Xabarlar (Messages)** — Telegram-style thread list + live conversation preview.
- **AI** — strategic-analysis insight cards + prompt suggestions.
- **Tasdiqlash (Approvals, Manager)** — request cards with approve/reject.
- **Signal / Holat (Anomalies / Cases, Audit)** — anomaly feed with AI scores and
  case tracking.
- **Profil** — account, settings, role switch, logout.

## Design system

Saroy (terracotta) palette from the original `tokens.css`, ported into
`lib/theme.dart` (`SfColors.light` / `SfColors.dark`). Fonts: **Manrope** (UI),
**Instrument Serif** (AI quotes), **JetBrains Mono** (numbers) — bundled under
`fonts/`. All charts (sparkline, area, donut, horizontal bars, 8-point star mark)
are drawn with `CustomPainter` — no chart packages.

## Project layout

```
lib/
  main.dart      role picker + app entry
  theme.dart     design tokens (SfColors) + SfTheme inherited widget
  data.dart      mock data + money formatting
  widgets.dart   shared widgets & chart painters
  screens.dart   all screen bodies
  console.dart   bottom-tab shell per role
```

## Run

```bash
flutter pub get
flutter run            # device / emulator
flutter run -d chrome  # web
```

> Demo only — sample data, no backend. The data layer (`lib/data.dart`) is the
> single place to wire a real API.
