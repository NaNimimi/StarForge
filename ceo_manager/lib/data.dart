import 'package:flutter/material.dart';
import 'theme.dart';

/// Display currency for all money formatting. Switchable from the design panel.
enum SfCurrency { uzs, usd, eur, rub }

const Map<SfCurrency, double> _rates = {
  SfCurrency.uzs: 1,
  SfCurrency.usd: 1 / 12650,
  SfCurrency.eur: 1 / 13700,
  SfCurrency.rub: 1 / 138,
};
const Map<SfCurrency, String> kCurrencyCode = {
  SfCurrency.uzs: 'UZS',
  SfCurrency.usd: 'USD',
  SfCurrency.eur: 'EUR',
  SfCurrency.rub: 'RUB',
};
const Map<SfCurrency, String> kCurrencySym = {
  SfCurrency.uzs: "so'm",
  SfCurrency.usd: '\$',
  SfCurrency.eur: '€',
  SfCurrency.rub: '₽',
};

/// Global current currency — set by [AppSettings.setCurrency]; read by the money
/// formatters so a switch re-renders every amount on the next rebuild.
SfCurrency gCurrency = SfCurrency.uzs;

/// Converted compact amount for non-UZS currencies: "$1.28M", "€680.0k", "₽142".
String _fmtConverted(num uzs) {
  final v = uzs * _rates[gCurrency]!;
  final sym = kCurrencySym[gCurrency]!;
  final neg = v < 0 ? '-' : '';
  final a = v.abs();
  if (a >= 1e6) return '$neg$sym${(a / 1e6).toStringAsFixed(2)}M';
  if (a >= 1e3) return '$neg$sym${(a / 1e3).toStringAsFixed(1)}k';
  return '$neg$sym${a.toStringAsFixed(gCurrency == SfCurrency.rub ? 0 : 1)}';
}

/// Format an amount with space thousands separators, e.g. "1 284 000 000 so'm".
/// Converts to the active [gCurrency] for non-UZS.
String fmtMoney(num uzs, {bool withSuffix = true}) {
  if (gCurrency != SfCurrency.uzs) return _fmtConverted(uzs);
  final neg = uzs < 0;
  final s = uzs.abs().round().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return '${neg ? '-' : ''}${buf.toString()}${withSuffix ? " so'm" : ''}';
}

/// Compact money for tight spaces: 342m, 1.3mlrd (UZS) or converted symbol form.
String fmtMoneyShort(num uzs) {
  if (gCurrency != SfCurrency.uzs) return _fmtConverted(uzs);
  if (uzs.abs() >= 1e9) return '${(uzs / 1e9).toStringAsFixed(1)} mlrd';
  if (uzs.abs() >= 1e6) return '${(uzs / 1e6).toStringAsFixed(0)}m';
  return uzs.toStringAsFixed(0);
}

/// Web-style compact money: "1.28 mlrd", "342.0 mln", "680k". Matches the
/// fmtMoney() formatting used across the React prototype's dashboards.
String fmtMoneyMln(num uzs) {
  if (gCurrency != SfCurrency.uzs) return _fmtConverted(uzs);
  final a = uzs.abs();
  final sign = uzs < 0 ? '-' : '';
  if (a >= 1e9) return '$sign${(a / 1e9).toStringAsFixed(2)} mlrd';
  if (a >= 1e6) return '$sign${(a / 1e6).toStringAsFixed(1)} mln';
  if (a >= 1e3) return '$sign${(a / 1e3).round()}k';
  return '$sign${a.round()}';
}

enum SfRole { ceo, manager, audit }

class TabSpec {
  final String id;
  final String label;
  final IconData icon;
  const TabSpec(this.id, this.label, this.icon);
}

class RoleConfig {
  final SfRole role;
  final String label;
  final String who;
  final String roleTitle;
  final String scope;
  final bool dark;
  final List<TabSpec> tabs;
  const RoleConfig({
    required this.role,
    required this.label,
    required this.who,
    required this.roleTitle,
    required this.scope,
    required this.dark,
    required this.tabs,
  });

  Color accent(SfColors c) => role == SfRole.audit ? const Color(0xFF7A4A82) : c.primary;
  SfColors get colors => dark ? SfColors.dark : SfColors.light;
}

/// A demo sign-in account, one per console. The password is shared for the demo
/// and shown on screen — there is no backend, this is a UX shell only.
class DemoUser {
  final SfRole role;
  final String login;
  final String password;
  const DemoUser(this.role, this.login, this.password);
}

const List<DemoUser> kDemoUsers = [
  DemoUser(SfRole.ceo, 'sardor', 'starforge'),
  DemoUser(SfRole.manager, 'dilnoza', 'starforge'),
  DemoUser(SfRole.audit, 'jamshid', 'starforge'),
];

const Map<SfRole, RoleConfig> kRoleConfigs = {
  SfRole.ceo: RoleConfig(
    role: SfRole.ceo,
    label: 'CEO',
    who: 'Sardor Rashidov',
    roleTitle: 'Bosh direktor',
    scope: 'Barcha filiallar',
    dark: false,
    tabs: [
      TabSpec('dash', 'Panel', Icons.home_rounded),
      TabSpec('groups', 'Guruh', Icons.workspaces_rounded),
      TabSpec('students', "O'quvchi", Icons.groups_rounded),
      TabSpec('ai', 'AI', Icons.auto_awesome_rounded),
      TabSpec('me', 'Profil', Icons.person_rounded),
    ],
  ),
  SfRole.manager: RoleConfig(
    role: SfRole.manager,
    label: 'Manager',
    who: "Dilnoza Yo'ldosheva",
    roleTitle: 'Filial menejeri',
    scope: 'Yunusobod',
    dark: false,
    tabs: [
      TabSpec('dash', 'Panel', Icons.home_rounded),
      TabSpec('students', "O'quvchi", Icons.groups_rounded),
      TabSpec('messages', 'Xabar', Icons.chat_bubble_rounded),
      TabSpec('approvals', 'Tasdiq', Icons.task_alt_rounded),
      TabSpec('me', 'Profil', Icons.person_rounded),
    ],
  ),
  SfRole.audit: RoleConfig(
    role: SfRole.audit,
    label: 'Audit',
    who: 'Jamshid Qodirov',
    roleTitle: 'Bosh auditor',
    scope: 'Nazorat',
    dark: true,
    tabs: [
      TabSpec('dash', 'Panel', Icons.shield_rounded),
      TabSpec('anomalies', 'Signal', Icons.flag_rounded),
      TabSpec('messages', 'Xabar', Icons.chat_bubble_rounded),
      TabSpec('cases', 'Holat', Icons.push_pin_rounded),
      TabSpec('me', 'Profil', Icons.person_rounded),
    ],
  ),
};

// ── Mock data sets (ported verbatim from admin-mobile.jsx) ──────────────

class Student {
  final String name;
  final String group;
  final int attendance;
  final String pay; // paid | debt | partial
  final num debt;
  const Student(this.name, this.group, this.attendance, this.pay, this.debt);
}

/// A full, deterministic demo profile derived from a student's name. The demo
/// has no backend, so per-student contact details (phones, parents, level) are
/// synthesised from the name — stable across rebuilds, never random.
class StudentProfile {
  final String firstName, lastName, level, phone;
  final String fatherName, fatherPhone, motherName, motherPhone;
  final int age;
  final String studentId, enrolled, branch;
  const StudentProfile({
    required this.firstName,
    required this.lastName,
    required this.level,
    required this.phone,
    required this.fatherName,
    required this.fatherPhone,
    required this.motherName,
    required this.motherPhone,
    required this.age,
    required this.studentId,
    required this.enrolled,
    required this.branch,
  });
}

const _kMaleNames = ['Rustam', 'Bobur', 'Jasur', 'Sardor', 'Otabek', 'Akmal',
    'Sherzod', 'Bekzod', 'Aziz', 'Davron', 'Farrux', "Ulug'bek"];
const _kFemaleNames = ['Dilbar', 'Nilufar', 'Madina', 'Zilola', 'Sevinch',
    'Gulnora', 'Malika', 'Shahnoza', 'Kamola', 'Feruza', 'Nigora', 'Saodat'];
const _kLevels = ['Beginner', 'Elementary', 'Pre-Intermediate', 'Intermediate',
    'Upper-Intermediate', 'Advanced'];
const _kDistricts = ['Yunusobod', 'Chilonzor', 'Mirobod', 'Sebzor', 'Yashnobod', 'Olmazor'];
const _kOpCodes = ['90', '91', '93', '94', '97', '98', '99', '88', '33'];

int _seedOf(String s) {
  var h = 0;
  for (final r in s.runes) {
    h = (h * 31 + r) & 0x7fffffff;
  }
  return h;
}

String _phoneFrom(int seed) {
  final op = _kOpCodes[seed % _kOpCodes.length];
  final a = ((seed ~/ 7) % 1000).toString().padLeft(3, '0');
  final b = ((seed ~/ 13) % 100).toString().padLeft(2, '0');
  final c = ((seed ~/ 17) % 100).toString().padLeft(2, '0');
  return '+998 $op $a-$b-$c';
}

/// Build the full profile for [s] (deterministic on the student's name).
StudentProfile studentProfile(Student s) {
  final parts = s.name.trim().split(RegExp(r'\s+'));
  final last = parts.first;
  final first = parts.length > 1 ? parts.sublist(1).join(' ') : '';
  final h = _seedOf(s.name);
  // Surname stem → male (-ov) and female (-ova) family forms.
  var stem = last;
  for (final suf in ['ova', 'ov', 'a']) {
    if (stem.length > suf.length && stem.endsWith(suf)) {
      stem = stem.substring(0, stem.length - suf.length);
      break;
    }
  }
  final enrYear = 2023 + h % 3;
  final enrMonth = (1 + (h ~/ 5) % 12).toString().padLeft(2, '0');
  final enrDay = (1 + (h ~/ 11) % 28).toString().padLeft(2, '0');
  return StudentProfile(
    firstName: first.isEmpty ? s.name : first,
    lastName: last,
    level: _kLevels[h % _kLevels.length],
    phone: _phoneFrom(h),
    fatherName: '${stem}ov ${_kMaleNames[h % _kMaleNames.length]}',
    fatherPhone: _phoneFrom(h ~/ 2 + 41),
    motherName: '${stem}ova ${_kFemaleNames[(h ~/ 3) % _kFemaleNames.length]}',
    motherPhone: _phoneFrom(h ~/ 4 + 77),
    age: 13 + h % 6,
    studentId: 'SF-${10000 + h % 89999}',
    enrolled: '$enrDay.$enrMonth.$enrYear',
    branch: s.group.contains('·') ? s.group.split('·').first.trim() : _kDistricts[h % _kDistricts.length],
  );
}

/// Days since the last call to this student's parents (demo: deterministic on
/// the name, range 0–37). Drives the green/amber/red "call status" indicator.
int studentCallDays(Student s) => _seedOf('call·${s.name}') % 38;

const List<Student> kStudents = [
  Student('Akbarov Akmal', '9-B Algebra', 96, 'paid', 0),
  Student('Azizova Madina', '9-B Algebra', 98, 'paid', 0),
  Student('Bakirov Sherzod', 'Algebra Mid', 88, 'debt', 600000),
  Student('Eshmatov Otabek', '9-B Algebra', 72, 'debt', 1200000),
  Student('Halimova Zilola', '9-B Algebra', 95, 'paid', 0),
  Student('Davronova Sevinch', 'Algebra Mid', 92, 'paid', 0),
  Student("G'aniyev Jasur", '10-V Geom', 89, 'partial', 300000),
  Student('Ibragimov Sardor', 'Algebra Mid', 91, 'paid', 0),
];

class Branch {
  final String name;
  final num revenue;
  final int students;
  final int attendance;
  final double trend;
  final Color mark;
  const Branch(this.name, this.revenue, this.students, this.attendance, this.trend, this.mark);
}

const List<Branch> kBranches = [
  Branch('Yunusobod', 342000000, 512, 94, 5.2, Color(0xFF4F7B3B)),
  Branch('Chilonzor', 318000000, 486, 92, 4.6, Color(0xFF4F7B3B)),
  Branch('Mirobod', 308000000, 478, 90, 3.1, Color(0xFFC68423)),
  Branch('Sebzor', 216000000, 366, 87, -1.2, Color(0xFFB33A2A)),
];

class Approval {
  final String id;
  final String title;
  final String who;
  final String sub;
  final num amount;
  final Color rail;

  /// When approved, a money request moves cash IN (true) or OUT (false) of the till.
  final bool inflow;
  const Approval(this.id, this.title, this.who, this.sub, this.amount, this.rail,
      {this.inflow = false});
}

const List<Approval> kApprovals = [
  Approval('A-1', "To'lov qaytarish", 'Akbarov Akmal', 'Ortiqcha · iyun', 600000, Color(0xFF4F7B3B)),
  Approval('A-2', "Ta'til", 'Yusupova N.', '24–26 May', 0, Color(0xFFB85535)),
  Approval('A-3', 'Yangi guruh', 'Ingliz B2', "18 o'rin", 0, Color(0xFFD89A2E)),
  Approval('A-4', 'Chiqarish', 'Eshmatov O.', '3+ oy qarz', 1200000, Color(0xFFB33A2A)),
];

// ── Ledger: the anti-fraud money-movement spine ─────────────────────────
// Every som that moves is one immutable row: tuition in, salary out, book
// sale, cash logged, refund. "Pulni yo'qotib bo'lmaydi" — money can't vanish.
class LedgerEntry {
  final String id;
  final String title;
  final String who;
  final num amount;
  final bool inflow; // true = money in, false = money out
  final String kind; // To'lov | Oylik | Kitob | Naqd | Tasdiq | Qaytarish
  final String channel; // Click | Payme | Uzum | Naqd | Tizim
  final String time;
  const LedgerEntry({
    required this.id,
    required this.title,
    required this.who,
    required this.amount,
    required this.inflow,
    required this.kind,
    required this.channel,
    required this.time,
  });
}

const List<LedgerEntry> kLedgerSeed = [
  LedgerEntry(
      id: 'L-2048', title: "Oylik to'lov", who: 'Azizova Madina', amount: 600000,
      inflow: true, kind: "To'lov", channel: 'Payme', time: '09:14'),
  LedgerEntry(
      id: 'L-2047', title: "Oylik to'lov", who: 'Halimova Zilola', amount: 600000,
      inflow: true, kind: "To'lov", channel: 'Click', time: '09:02'),
  LedgerEntry(
      id: 'L-2046', title: 'Kitob sotuvi · Grammar 4', who: "G'aniyev Jasur", amount: 85000,
      inflow: true, kind: 'Kitob', channel: 'Naqd', time: 'Kecha 17:40'),
  LedgerEntry(
      id: 'L-2045', title: "O'qituvchi oyligi", who: 'Nigora Karimova', amount: 4200000,
      inflow: false, kind: 'Oylik', channel: 'Tizim', time: 'Kecha 15:20'),
  LedgerEntry(
      id: 'L-2044', title: 'Naqd · qabul', who: 'Ibragimov Sardor', amount: 600000,
      inflow: true, kind: 'Naqd', channel: 'Naqd', time: 'Kecha 11:05'),
];

class Anomaly {
  final String title;
  final String kind;
  final String branch;
  final int score;
  final String sev; // high | med | low
  const Anomaly(this.title, this.kind, this.branch, this.score, this.sev);
}

const List<Anomaly> kAnomalies = [
  Anomaly('Davomat 100% · 21 kun', 'Davomat', 'Sebzor', 94, 'high'),
  Anomaly('48 Up karta/hafta', 'Karta', 'Mirobod', 72, 'med'),
  Anomaly('Naqd · kvitansiyasiz', 'Moliya', 'Sebzor', 88, 'high'),
  Anomaly("Tungi profil o'zgarishi", 'Kirish', 'Chilonzor', 34, 'low'),
  Anomaly("So'rovnoma · 30s", "So'rovnoma", 'Yunusobod', 61, 'med'),
];

class AuditCase {
  final String id;
  final String title;
  final String sev;
  final String status; // open | review | closed
  const AuditCase(this.id, this.title, this.sev, this.status);
}

const List<AuditCase> kCases = [
  AuditCase('C-0042', 'Sebzor · kvitansiyasiz naqd', 'high', 'open'),
  AuditCase('C-0041', 'Mirobod · karta nomutanosibligi', 'med', 'review'),
  AuditCase('C-0040', 'Davomat anomaliyasi · Fizika', 'high', 'open'),
  AuditCase('C-0039', "So'rovnoma yaxlitligi", 'med', 'review'),
  AuditCase('C-0038', "Tungi profil o'zgarishi", 'low', 'closed'),
];

class Thread {
  final String name;
  final String group;
  final String last;
  final String time;
  final int unread;
  final bool online;
  final bool isGroup;
  const Thread(this.name, this.group, this.last, this.time,
      {this.unread = 0, this.online = false, this.isGroup = false});
}

// Manager (Dilnoza · Yunusobod) talks to her teachers and parents.
const List<Thread> kThreads = [
  Thread('Nigora Karimova', "O'qituvchi · Matematika", "Ertangi yig'ilishga tayyorman", '14:42', online: true),
  Thread("Matematika bo'limi", 'Guruh · 12 a\'zo', 'Siz: Yangi mavzular...', '13:20', isGroup: true),
  Thread('Akbarova Dilnoza', 'Ota-ona · 9-B', 'Rahmat ustoz!', '12:18', unread: 2),
  Thread('Aziz Tursunov', "O'qituvchi · Ingliz", 'Yangi guruh ochsak?', '11:05', unread: 1, online: true),
  Thread("Qabul bo'limi", 'Guruh · 8 a\'zo', 'Bugun 6 ta yangi lid', 'Du', unread: 3, isGroup: true),
];

// CEO (Sardor) talks to branch managers, finance and the board.
const List<Thread> kThreadsCeo = [
  Thread("Dilnoza Yo'ldosheva", 'Menejer · Yunusobod', 'Oylik hisobot tayyor', '14:42', online: true),
  Thread('Filial menejerlari', "Guruh · 4 a'zo", 'Siz: Reyting yangilandi', '13:20', isGroup: true, unread: 1),
  Thread('Jamshid Qodirov', 'Bosh auditor · Nazorat', "Sebzor bo'yicha signal bor", '12:18', unread: 2),
  Thread('Aziz Karimov', 'Moliya direktori', 'Byudjet tasdiqlansinmi?', '11:05', online: true),
  Thread('Kengash', "Guruh · 6 a'zo", 'Keyingi chorak rejasi', 'Du', unread: 3, isGroup: true),
];

// Audit (Jamshid) talks to the CEO, security, legal and branch managers under review.
const List<Thread> kThreadsAudit = [
  Thread('Sardor Rashidov', 'CEO · Boshqaruv', 'Hisobotni kutaman', '15:10', unread: 1),
  Thread("Xavfsizlik bo'limi", "Guruh · 5 a'zo", 'Kamera loglari yuborildi', '13:48', isGroup: true, online: true),
  Thread('Sebzor menejeri', 'Filial · Sebzor', 'Kvitansiyalar tayyor', '12:30', unread: 2),
  Thread("Yuridik bo'lim", "Guruh · 3 a'zo", "Hujjatlar ko'rib chiqildi", '10:15', isGroup: true),
  Thread('Mirobod menejeri', 'Filial · Mirobod', 'Karta tushuntirishi', 'Du'),
];

// ── Role-scoped datasets ────────────────────────────────────────────────
// Each console sees its own slice of the world: the CEO sees all branches,
// the manager only Yunusobod, the auditor the whole network under review.

/// CEO roster — a cross-branch sample (groups are tagged by branch).
const List<Student> kStudentsCeo = [
  Student('Akbarov Akmal', 'Yunusobod · 9-B', 96, 'paid', 0),
  Student('Azizova Madina', 'Yunusobod · 9-B', 98, 'paid', 0),
  Student('Bakirov Sherzod', 'Chilonzor · Algebra', 88, 'debt', 600000),
  Student('Eshmatov Otabek', 'Sebzor · 9-B', 72, 'debt', 1200000),
  Student('Halimova Zilola', 'Mirobod · 10-V', 95, 'paid', 0),
  Student('Davronova Sevinch', 'Chilonzor · Mid', 92, 'paid', 0),
  Student("G'aniyev Jasur", 'Mirobod · 10-V', 89, 'partial', 300000),
  Student('Ibragimov Sardor', 'Yunusobod · Mid', 91, 'paid', 0),
  Student('Yusupova Nilufar', 'Sebzor · Beginner', 68, 'debt', 900000),
  Student('Rustamov Bekzod', 'Chilonzor · 11-A', 84, 'partial', 450000),
];

/// Manager roster — only Dilnoza's Yunusobod groups.
const List<Student> kStudentsManager = [
  Student('Akbarov Akmal', '9-B Algebra', 96, 'paid', 0),
  Student('Azizova Madina', '9-B Algebra', 98, 'paid', 0),
  Student('Halimova Zilola', '9-B Algebra', 95, 'paid', 0),
  Student('Davronova Sevinch', 'Algebra Mid', 92, 'paid', 0),
  Student('Eshmatov Otabek', '9-B Algebra', 72, 'debt', 1200000),
  Student('Ibragimov Sardor', 'Algebra Mid', 91, 'paid', 0),
];

/// Manager only runs a single branch.
const List<Branch> kBranchesManager = [
  Branch('Yunusobod', 342000000, 512, 94, 5.2, Color(0xFF4F7B3B)),
];

/// CEO ledger — branch-level daily flows, larger scale.
const List<LedgerEntry> kLedgerCeo = [
  LedgerEntry(
      id: 'L-9001', title: 'Yunusobod · kunlik tushum', who: 'Filial', amount: 11400000,
      inflow: true, kind: "To'lov", channel: 'Payme', time: '09:40'),
  LedgerEntry(
      id: 'L-9000', title: 'Chilonzor · kunlik tushum', who: 'Filial', amount: 9800000,
      inflow: true, kind: "To'lov", channel: 'Click', time: '09:20'),
  LedgerEntry(
      id: 'L-8999', title: 'Marketing · Instagram', who: 'SMM', amount: 6500000,
      inflow: false, kind: 'Xarajat', channel: 'Tizim', time: 'Kecha 18:10'),
  LedgerEntry(
      id: 'L-8998', title: 'Mirobod · ijara', who: 'Bino', amount: 18000000,
      inflow: false, kind: 'Ijara', channel: 'Tizim', time: 'Kecha 15:00'),
  LedgerEntry(
      id: 'L-8997', title: 'Sebzor · kunlik tushum', who: 'Filial', amount: 5200000,
      inflow: true, kind: "To'lov", channel: 'Naqd', time: 'Kecha 11:30'),
];

/// Headline numbers for the dashboard, per console.
class DashStats {
  final num revenue;
  final String students;
  final num debt;
  final String aiQuote;
  const DashStats(
      {required this.revenue, required this.students, required this.debt, required this.aiQuote});
}

const Map<SfRole, DashStats> kDashStats = {
  SfRole.ceo: DashStats(
      revenue: 1284000000,
      students: '1 842',
      debt: 84000000,
      aiQuote: 'Sebzorda churn 6.2% — 2x yuqori. Tekshiring.'),
  SfRole.manager: DashStats(
      revenue: 342000000,
      students: '512',
      debt: 22400000,
      aiQuote: '38 oila qarzdor. 12 tasi 30 kundan oshgan.'),
  SfRole.audit: DashStats(revenue: 0, students: '0', debt: 0, aiQuote: ''),
};

// ── Per-role selectors ──────────────────────────────────────────────────
List<Student> studentsFor(SfRole r) => r == SfRole.manager ? kStudentsManager : kStudentsCeo;
List<Branch> branchesFor(SfRole r) => r == SfRole.manager ? kBranchesManager : kBranches;
List<Approval> approvalsFor(SfRole r) => r == SfRole.manager ? kApprovals : const <Approval>[];
List<LedgerEntry> ledgerFor(SfRole r) => r == SfRole.ceo ? kLedgerCeo : kLedgerSeed;
List<Thread> threadsFor(SfRole r) => switch (r) {
      SfRole.ceo => kThreadsCeo,
      SfRole.manager => kThreads,
      SfRole.audit => kThreadsAudit,
    };
