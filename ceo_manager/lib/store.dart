import 'package:flutter/widgets.dart';
import 'data.dart';
import 'widgets.dart';

/// A chat turn in the AI assistant.
class AiTurn {
  final String text;
  final bool mine;
  const AiTurn(this.text, {required this.mine});
}

/// One message inside a conversation thread.
class ChatMsg {
  final String text;
  final bool mine;
  const ChatMsg(this.text, {required this.mine});
}

/// A live conversation: its [meta] (from [Thread]) plus a growing message log.
class ChatThread {
  final Thread meta;
  final List<ChatMsg> messages;
  ChatThread(this.meta, this.messages);
}

/// One saved AI conversation — its title (from the first question) and turns.
class AiConversation {
  String title;
  final List<AiTurn> turns;
  AiConversation(this.title, this.turns);
}

/// In-memory app state for the demo (no backend yet — "Backend ulanmagan").
///
/// Holds the live approval queue, the money-movement ledger, and the AI chat
/// transcript. Resolving a money approval posts an immutable ledger row — the
/// Approvals → Ledger spine the product is built around.
class AppStore extends ChangeNotifier {
  final SfRole role;
  final List<Student> students;
  final List<Branch> branches;
  final List<Approval> approvals;
  final List<LedgerEntry> ledger;
  final List<Anomaly> anomalies;
  final List<AuditCase> cases;
  final List<ChatThread> threads;

  // ── AI assistant: multiple conversations with a history sidebar ─────────
  final List<AiConversation> conversations = [
    AiConversation('Yangi suhbat', []),
    AiConversation('Churn tahlili · Sebzor', const [
      AiTurn('Sebzorda churn nega oshdi?', mine: true),
      AiTurn("Sebzorda churn 6.2% — 3 o'qituvchi almashdi va 6 o'quvchi davomati tushdi. "
          "Ota-onalarga qo'ng'iroq tavsiya etaman.", mine: false),
    ]),
    AiConversation('Daromad prognozi', const [
      AiTurn('Kelgusi oy daromadi qancha?', mine: true),
      AiTurn("~1.34 mlrd so'm (+4%). Ingliz B2 yangi guruhi +52 mln so'm qo'shadi.", mine: false),
    ]),
  ];
  int activeConv = 0;
  List<AiTurn> get chat => conversations[activeConv].turns;

  /// Start a fresh conversation (reuses an already-empty one).
  void newConversation() {
    if (chat.isNotEmpty) {
      conversations.insert(0, AiConversation('Yangi suhbat', []));
      activeConv = 0;
    }
    notifyListeners();
  }

  void selectConversation(int i) {
    activeConv = i;
    notifyListeners();
  }

  AppStore({
    required this.role,
    required this.students,
    required this.branches,
    required this.approvals,
    required this.ledger,
    required this.anomalies,
    required this.cases,
    required this.threads,
  });

  /// Headline KPI numbers for this console's dashboard.
  DashStats get stats => kDashStats[role]!;

  /// The logged-in user's chosen avatar (null = their default photo). Set from
  /// the avatar picker; read by the top bar and profile so it updates live.
  AvatarChoice? avatarChoice;
  void setAvatar(AvatarChoice? choice) {
    avatarChoice = choice;
    notifyListeners();
  }

  /// User-edited profile fields (null = fall back to the role config defaults).
  String? nameOverride;
  String? titleOverride;
  void setProfile({String? name, String? title}) {
    if (name != null) nameOverride = name.trim().isEmpty ? null : name.trim();
    if (title != null) titleOverride = title.trim().isEmpty ? null : title.trim();
    notifyListeners();
  }

  // ── Messages: pin & archive (Telegram-style) ───────────────────────────
  final Set<int> pinned = {};
  final Set<int> archived = {};
  void togglePin(int idx) {
    pinned.contains(idx) ? pinned.remove(idx) : pinned.add(idx);
    notifyListeners();
  }

  void toggleArchive(int idx) {
    archived.contains(idx) ? archived.remove(idx) : archived.add(idx);
    pinned.remove(idx);
    notifyListeners();
  }

  /// Build the demo state for [role] — each console gets its own slice of data.
  factory AppStore.seed(SfRole role) => AppStore(
        role: role,
        students: studentsFor(role),
        branches: branchesFor(role),
        approvals: List<Approval>.from(approvalsFor(role)),
        ledger: List<LedgerEntry>.from(ledgerFor(role)),
        anomalies: List<Anomaly>.from(kAnomalies),
        cases: List<AuditCase>.from(kCases),
        threads: threadsFor(role)
            .map((t) => ChatThread(t, [ChatMsg(t.last, mine: false)]))
            .toList(),
      );

  int get pendingCount => approvals.length;

  int _seq = 3000;
  int _caseSeq = 43;

  // ── Audit: anomalies → cases ──────────────────────────────────────────
  /// Per-id status overrides so const seed cases stay immutable.
  final Map<String, String> _caseStatus = {};
  String statusOf(AuditCase c) => _caseStatus[c.id] ?? c.status;

  void setCaseStatus(AuditCase c, String status) {
    _caseStatus[c.id] = status;
    notifyListeners();
  }

  void dismissAnomaly(Anomaly a) {
    anomalies.remove(a);
    notifyListeners();
  }

  /// Promote an anomaly into a tracked audit case.
  void anomalyToCase(Anomaly a) {
    anomalies.remove(a);
    final id = 'C-${(_caseSeq++).toString().padLeft(4, '0')}';
    cases.insert(0, AuditCase(id, '${a.branch} · ${a.title}', a.sev == 'low' ? 'low' : a.sev == 'med' ? 'med' : 'high', 'open'));
    _caseStatus[id] = 'open';
    notifyListeners();
  }

  // ── Messages ──────────────────────────────────────────────────────────
  void sendMessage(int threadIdx, String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    threads[threadIdx].messages.add(ChatMsg(t, mine: true));
    notifyListeners();
  }

  /// Approve or reject a request. Approving a money request ( amount > 0 )
  /// appends a ledger entry so the cash movement is recorded and auditable.
  void resolve(Approval a, {required bool approved}) {
    approvals.removeWhere((x) => x.id == a.id);
    if (approved && a.amount > 0) {
      ledger.insert(
        0,
        LedgerEntry(
          id: 'L-${_seq++}',
          title: a.title,
          who: a.who,
          amount: a.amount,
          inflow: a.inflow,
          kind: 'Tasdiq',
          channel: 'Tizim',
          time: 'Hozir',
        ),
      );
    }
    notifyListeners();
  }

  /// Net balance = inflows − outflows across the ledger.
  num get balance =>
      ledger.fold<num>(0, (sum, e) => sum + (e.inflow ? e.amount : -e.amount));

  num get inflowTotal =>
      ledger.where((e) => e.inflow).fold<num>(0, (s, e) => s + e.amount);

  num get outflowTotal =>
      ledger.where((e) => !e.inflow).fold<num>(0, (s, e) => s + e.amount);

  void sendChat(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    final conv = conversations[activeConv];
    if (conv.turns.isEmpty) {
      conv.title = t.length > 32 ? '${t.substring(0, 32)}…' : t;
    }
    conv.turns.add(AiTurn(t, mine: true));
    conv.turns.add(AiTurn(_reply(t), mine: false));
    notifyListeners();
  }

  /// Offline canned reasoning so the chat feels alive without a backend.
  String _reply(String q) {
    final s = q.toLowerCase();
    if (s.contains('churn') || s.contains('ketish') || s.contains('risk')) {
      return 'Sebzor filialida churn 6.2% — markaz bo‘yicha 2x yuqori. Asosiy sabab: '
          "3 o'qituvchi almashdi va 6 o'quvchining davomati 75% dan tushdi. "
          'Ota-onalarga bugun qo‘ng‘iroq qilishni tavsiya qilaman.';
    }
    if (s.contains('daromad') || s.contains('prognoz') || s.contains('revenue')) {
      return 'Joriy sur’atda kelgusi oy daromadi ~1.34 mlrd so‘m (+4%). '
          'Ingliz B2 to‘ldi — yangi guruh oyiga +52 mln so‘m qo‘shadi.';
    }
    if (s.contains('qarz') || s.contains("to'lov") || s.contains('debt')) {
      return '142 oila qarzdor (jami 84 mln so‘m), 38 tasi 30 kundan oshgan. '
          'Eng katta 5 tasiga eslatma yuborib, to‘lov-kechiktirish taklif qilsak bo‘ladi.';
    }
    if (s.contains('reyting') || s.contains('filial') || s.contains('branch')) {
      return 'Filiallar reytingi (daromad): Yunusobod → Chilonzor → Mirobod → Sebzor. '
          'Sebzor pasaymoqda (-1.2%), e’tibor talab qiladi.';
    }
    return 'Savolingizni qabul qildim. Demo rejimida ishlayapman (backend ulanmagan) — '
        'davomat, to‘lov yoki churn bo‘yicha aniq so‘rasangiz, batafsil tahlil beraman.';
  }
}

/// Inherited access to [AppStore]; rebuilds dependents on [notifyListeners].
class AppScope extends InheritedNotifier<AppStore> {
  const AppScope({super.key, required AppStore store, required super.child})
      : super(notifier: store);

  static AppStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope?.notifier != null, 'AppScope not found in context');
    return scope!.notifier!;
  }
}
