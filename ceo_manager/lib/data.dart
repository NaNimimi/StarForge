import 'package:flutter/material.dart';
import 'theme.dart';

/// Format an amount in UZS with space thousands separators, e.g. "1 284 000 000 so'm".
String fmtMoney(num uzs, {bool withSuffix = true}) {
  final neg = uzs < 0;
  final s = uzs.abs().round().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return '${neg ? '-' : ''}${buf.toString()}${withSuffix ? " so'm" : ''}';
}

/// Compact money for tight spaces: 342m, 1.3mlrd.
String fmtMoneyShort(num uzs) {
  if (uzs.abs() >= 1e9) return '${(uzs / 1e9).toStringAsFixed(1)} mlrd';
  if (uzs.abs() >= 1e6) return '${(uzs / 1e6).toStringAsFixed(0)}m';
  return uzs.toStringAsFixed(0);
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
      TabSpec('students', "O'quvchi", Icons.groups_rounded),
      TabSpec('messages', 'Xabar', Icons.chat_bubble_rounded),
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

const List<Thread> kThreads = [
  Thread('Nigora Karimova', "O'qituvchi · Matematika", "Ertangi yig'ilishga tayyorman", '14:42', online: true),
  Thread("Matematika bo'limi", 'Guruh · 12 a\'zo', 'Siz: Yangi mavzular...', '13:20', isGroup: true),
  Thread('Akbarova Dilnoza', 'Ota-ona · 9-B', 'Rahmat ustoz!', '12:18', unread: 2),
  Thread('Aziz Tursunov', "O'qituvchi · Ingliz", 'Yangi guruh ochsak?', '11:05', unread: 1, online: true),
  Thread("Qabul bo'limi", 'Guruh · 8 a\'zo', 'Bugun 6 ta yangi lid', 'Du', unread: 3, isGroup: true),
];
