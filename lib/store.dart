import 'package:flutter/material.dart'
    show ChangeNotifier, DateTimeRange, IconData, Icons;
import 'package:flutter/widgets.dart' show BuildContext, InheritedNotifier;
import 'data.dart';
import 'widgets.dart';

/// A chat turn in the AI assistant.
class AiTurn {
  final String text;
  final bool mine;
  const AiTurn(this.text, {required this.mine});
}

/// Payload carried by a message in a conversation thread. Files stay local in
/// this offline demo; swapping the store for a backend later only needs to
/// upload [path] and retain its remote URL.
enum ChatMessageKind { text, image, video, voice }

/// One message inside a conversation thread.
class ChatMsg {
  final String text;
  final bool mine;
  final ChatMessageKind kind;
  final String? path;
  final Duration? duration;
  const ChatMsg(
    this.text, {
    required this.mine,
    this.kind = ChatMessageKind.text,
    this.path,
    this.duration,
  });
}

/// A live conversation: its [meta] (from [Thread]) plus a growing message log.
class ChatThread {
  final Thread meta;
  final List<ChatMsg> messages;
  ChatThread(this.meta, this.messages);
}

/// A group created locally before a backend is connected. Seed groups are
/// still derived from student data, while this model keeps newly created empty
/// groups visible in the mobile UI as well.
class ManagedGroup {
  final String name;
  final String branch;
  final String teacher;
  final String schedule;
  final String level;
  final String status; // active | paused | closed
  const ManagedGroup({
    required this.name,
    required this.branch,
    required this.teacher,
    required this.schedule,
    required this.level,
    this.status = 'active',
  });
}

/// Minimal staff record used by the offline mobile preview. The API adapter
/// can map its own DTO to this shape later without changing the form UI.
class StaffMember {
  final String firstName;
  final String lastName;
  final String username;
  final String phone;
  final String? email;
  final String branch;
  final String department;
  final String subject;
  final String qualification;
  final String salaryType;
  final String rate;
  final String gender;
  final String hireDate;
  final List<String> groups;
  const StaffMember({
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.phone,
    required this.email,
    required this.branch,
    required this.department,
    required this.subject,
    required this.qualification,
    required this.salaryType,
    required this.rate,
    required this.gender,
    required this.hireDate,
    this.groups = const <String>[],
  });

  String get fullName => '$firstName $lastName'.trim();

  /// Staff records are immutable so a transfer creates a complete new record
  /// instead of accidentally dropping HR data that is not shown in the UI.
  StaffMember copyWith({String? branch, String? department}) => StaffMember(
    firstName: firstName,
    lastName: lastName,
    username: username,
    phone: phone,
    email: email,
    branch: branch ?? this.branch,
    department: department ?? this.department,
    subject: subject,
    qualification: qualification,
    salaryType: salaryType,
    rate: rate,
    gender: gender,
    hireDate: hireDate,
    groups: groups,
  );
}

/// A department is store-owned rather than page-owned. This is important: a
/// transfer, termination, or manager appointment must remain visible after a
/// user leaves and reopens the Department screen.
class DepartmentRecord {
  String name;
  String manager;
  String description;
  String branch;
  String status;
  String responsible;
  String createdAt;
  final List<String> initialStaffUsernames;
  final List<DepartmentChange> history;

  DepartmentRecord({
    required this.name,
    required this.manager,
    required this.description,
    this.branch = 'Barcha filiallar',
    this.status = 'active',
    this.responsible = 'Tayinlanmagan',
    this.createdAt = '—',
    List<String>? initialStaffUsernames,
    List<DepartmentChange>? history,
  }) : initialStaffUsernames = initialStaffUsernames ?? <String>[],
       history = history ?? <DepartmentChange>[];
}

/// Compact parent/child projection used by the modern parent list. It is
/// intentionally derived from canonical students instead of maintaining a
/// second mutable copy of the same child data.
class ParentSummary {
  final String fullName;
  final String phone;
  final Student child;
  final String teacher;
  final String educationStarted;
  final DateTime lastCallAt;

  const ParentSummary({
    required this.fullName,
    required this.phone,
    required this.child,
    required this.teacher,
    required this.educationStarted,
    required this.lastCallAt,
  });
}

/// Business metrics shared by group cards and the CEO group detail. These
/// values are computed from the same store collections as the list screens,
/// so totals cannot drift between pages in offline mode.
class GroupAnalytics {
  final int studentCount;
  final int averageAttendance;
  final int debtorCount;
  final num debt;
  final num income;

  const GroupAnalytics({
    required this.studentCount,
    required this.averageAttendance,
    required this.debtorCount,
    required this.debt,
    required this.income,
  });
}

/// A locally-created operational note. Notes are kept in the shared store so
/// they remain visible in the group history after navigating away and back.
class GroupNote {
  final String groupName;
  final String text;
  final DateTime createdAt;

  const GroupNote({
    required this.groupName,
    required this.text,
    required this.createdAt,
  });
}

/// An exam scheduled from the group quick actions. The API can later map this
/// exact record to its exam endpoint without changing the group UI.
class GroupExam {
  final String groupName;
  final String title;
  final DateTime scheduledAt;

  const GroupExam({
    required this.groupName,
    required this.title,
    required this.scheduledAt,
  });
}

class DepartmentChange {
  final IconData icon;
  final String title;
  final String detail;
  final String time;
  const DepartmentChange({
    required this.icon,
    required this.title,
    required this.detail,
    this.time = 'Hozir',
  });
}

/// Human-readable audit trail for the History page and dashboard preview.
class ActivityEvent {
  final IconData icon;
  final String title;
  final String detail;
  final String time;
  final String kind;
  const ActivityEvent({
    required this.icon,
    required this.title,
    required this.detail,
    required this.time,
    required this.kind,
  });
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
  final Map<ChatMsg, String> messageReactions = <ChatMsg, String>{};

  /// Role-scoped productivity state used by the command centre.
  ///
  /// An [AppStore] belongs to exactly one signed-in role, so route ids can stay
  /// compact here. Every rendering/navigation surface still validates them
  /// against the canonical permission matrix before exposing or opening one.
  final Set<String> favoriteCommandRoutes = <String>{};
  final List<String> recentCommandRoutes = <String>[];
  final Set<String> readLocalNotificationIds = <String>{};
  final Set<String> hiddenLocalNotificationIds = <String>{};

  bool isFavoriteCommand(String route) => favoriteCommandRoutes.contains(route);

  void toggleFavoriteCommand(String route) {
    final value = route.trim();
    if (value.isEmpty) return;
    favoriteCommandRoutes.contains(value)
        ? favoriteCommandRoutes.remove(value)
        : favoriteCommandRoutes.add(value);
    notifyListeners();
  }

  /// Remembers a successfully-opened destination, newest first.
  ///
  /// Keeping a small, deduplicated window prevents an unbounded navigation log
  /// while still making the command centre useful on a phone.
  void rememberOpenedRoute(String route) {
    final value = route.trim();
    if (value.isEmpty) return;
    if (recentCommandRoutes.isNotEmpty && recentCommandRoutes.first == value) {
      return;
    }
    recentCommandRoutes
      ..remove(value)
      ..insert(0, value);
    if (recentCommandRoutes.length > 8) {
      recentCommandRoutes.removeRange(8, recentCommandRoutes.length);
    }
    notifyListeners();
  }

  bool localNotificationIsRead(String id) =>
      readLocalNotificationIds.contains(id);

  bool localNotificationIsHidden(String id) =>
      hiddenLocalNotificationIds.contains(id);

  void markLocalNotificationRead(String id) {
    if (readLocalNotificationIds.add(id)) {
      notifyListeners();
    }
  }

  void markAllLocalNotificationsRead(Iterable<String> ids) {
    final before = readLocalNotificationIds.length;
    readLocalNotificationIds.addAll(ids);
    if (before != readLocalNotificationIds.length) {
      notifyListeners();
    }
  }

  void hideLocalNotification(String id) {
    final hiddenChanged = hiddenLocalNotificationIds.add(id);
    final readChanged = readLocalNotificationIds.add(id);
    if (hiddenChanged || readChanged) {
      notifyListeners();
    }
  }

  String? reactionFor(ChatMsg message) => messageReactions[message];

  void setMessageReaction(ChatMsg message, String reaction) {
    if (messageReactions[message] == reaction) {
      messageReactions.remove(message);
    } else {
      messageReactions[message] = reaction;
    }
    notifyListeners();
  }

  /// Runtime-created objects. They deliberately live in the store so a form
  /// can update every related screen in this offline preview immediately.
  final List<ManagedGroup> extraGroups = [];
  final List<GroupNote> groupNotes = [];
  final List<GroupExam> groupExams = [];
  final Map<String, DateTime> groupDebtReminders = {};
  final Set<String> pinnedGroups = {};
  final List<DepartmentRecord> departments = [
    DepartmentRecord(
      name: 'Matematika',
      manager: 'Nigora Karimova',
      description: 'Algebra va geometriya',
      branch: 'Yunusobod',
      responsible: 'Sardor Rashidov',
      createdAt: '12.08.2021',
      history: [
        const DepartmentChange(
          icon: Icons.account_circle_rounded,
          title: 'Rahbar tayinlandi',
          detail: 'Nigora Karimova',
          time: '12.08.2021',
        ),
      ],
    ),
    DepartmentRecord(
      name: 'English',
      manager: 'Aziz Tursunov',
      description: 'IELTS va umumiy ingliz tili',
      branch: 'Chilonzor',
      responsible: 'Dilnoza Yo‘ldosheva',
      createdAt: '03.02.2022',
      history: [
        const DepartmentChange(
          icon: Icons.account_circle_rounded,
          title: 'Rahbar tayinlandi',
          detail: 'Aziz Tursunov',
          time: '03.02.2022',
        ),
      ],
    ),
    DepartmentRecord(
      name: 'Reception',
      manager: 'Gulnora Saidova',
      description: 'Qabul va ota-onalar aloqasi',
      branch: 'Mirobod',
      responsible: 'Sardor Rashidov',
      createdAt: '18.05.2023',
      history: [
        const DepartmentChange(
          icon: Icons.account_circle_rounded,
          title: 'Rahbar tayinlandi',
          detail: 'Gulnora Saidova',
          time: '18.05.2023',
        ),
      ],
    ),
  ];
  final List<StaffMember> staff = [
    const StaffMember(
      firstName: 'Nigora',
      lastName: 'Karimova',
      username: 'n.karimova',
      phone: '+998 90 123-45-67',
      email: 'nigora@starforge.uz',
      branch: 'Yunusobod',
      department: 'Matematika',
      subject: 'Algebra',
      qualification: 'Senior teacher',
      salaryType: 'Monthly',
      rate: '8 400 000',
      gender: 'Female',
      hireDate: '12.08.2021',
      groups: ['9-B Algebra', 'Algebra Mid'],
    ),
    const StaffMember(
      firstName: 'Aziz',
      lastName: 'Tursunov',
      username: 'a.tursunov',
      phone: '+998 91 223-10-20',
      email: null,
      branch: 'Chilonzor',
      department: 'English',
      subject: 'IELTS',
      qualification: 'Teacher',
      salaryType: 'Monthly',
      rate: '7 800 000',
      gender: 'Male',
      hireDate: '03.02.2022',
      groups: ['Ingliz B2'],
    ),
    const StaffMember(
      firstName: 'Gulnora',
      lastName: 'Saidova',
      username: 'g.saidova',
      phone: '+998 93 555-22-11',
      email: null,
      branch: 'Mirobod',
      department: 'Reception',
      subject: 'Operations',
      qualification: 'Manager',
      salaryType: 'Monthly',
      rate: '5 600 000',
      gender: 'Female',
      hireDate: '18.05.2023',
    ),
  ];
  final List<ActivityEvent> activities = [
    const ActivityEvent(
      icon: Icons.payments_rounded,
      title: "Yangi to'lov qabul qilindi",
      detail: 'Yunusobod · 1 200 000 so‘m',
      time: '2 daqiqa',
      kind: 'payment',
    ),
    const ActivityEvent(
      icon: Icons.person_add_alt_1_rounded,
      title: "O'quvchi qo'shildi",
      detail: 'Chilonzor · 12-sinf',
      time: '14 daqiqa',
      kind: 'student',
    ),
    const ActivityEvent(
      icon: Icons.workspaces_rounded,
      title: 'Guruh yangilandi',
      detail: 'Algebra Mid · jadval o‘zgardi',
      time: '1 soat',
      kind: 'group',
    ),
    const ActivityEvent(
      icon: Icons.flag_rounded,
      title: 'Audit flag ochildi',
      detail: 'Mirobod · проверка посещаемости',
      time: '2 soat',
      kind: 'audit',
    ),
  ];

  // ── Shared CEO report context ────────────────────────────────────────
  // The selected branch and period are deliberately store-level state rather
  // than local widget state. This makes dashboard, report and detail pages
  // describe the same slice of the business after the user changes a filter.
  String selectedBranch = '__all';
  DateTimeRange selectedRange = DateTimeRange(
    start: DateTime(
      DateTime.now().year,
      DateTime.now().month - 1,
      DateTime.now().day,
    ),
    end: DateTime.now(),
  );

  bool get allBranchesSelected => selectedBranch == '__all';
  Branch? get selectedBranchData {
    for (final branch in branches) {
      if (branch.name == selectedBranch) return branch;
    }
    return null;
  }

  int get rangeDays => selectedRange.duration.inDays.abs() + 1;

  bool get hasCustomReportFilters {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 1, now.day);
    final selectedStart = selectedRange.start;
    final selectedEnd = selectedRange.end;
    return !allBranchesSelected ||
        selectedStart.year != start.year ||
        selectedStart.month != start.month ||
        selectedStart.day != start.day ||
        selectedEnd.year != now.year ||
        selectedEnd.month != now.month ||
        selectedEnd.day != now.day;
  }

  /// A deterministic demo multiplier. It makes the values visibly respond to
  /// a calendar selection until the data source is connected, without claiming
  /// to be a real historical calculation.
  double get rangeFactor => (rangeDays / 31).clamp(0.12, 12.0);

  num scopedRevenue(num allRevenue) =>
      ((selectedBranchData?.revenue ?? allRevenue) * rangeFactor).round();

  int scopedStudents(int allStudents) =>
      selectedBranchData?.students ?? allStudents;

  int scopedAttendance(int allAttendance) =>
      selectedBranchData?.attendance ?? allAttendance;

  void setBranchScope(String value) {
    if (selectedBranch == value) return;
    selectedBranch = value;
    notifyListeners();
  }

  void setDateRange(DateTimeRange range) {
    selectedRange = DateTimeRange(
      start: DateTime(range.start.year, range.start.month, range.start.day),
      end: DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59),
    );
    notifyListeners();
  }

  void resetReportFilters() {
    selectedBranch = '__all';
    final now = DateTime.now();
    selectedRange = DateTimeRange(
      start: DateTime(now.year, now.month - 1, now.day),
      end: now,
    );
    notifyListeners();
  }

  // ── AI assistant: multiple conversations with a history sidebar ─────────
  final List<AiConversation> conversations = [
    AiConversation('Yangi suhbat', []),
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

  void addAiUserTurn(String text) {
    final value = text.trim();
    if (value.isEmpty) return;
    final conversation = conversations[activeConv];
    if (conversation.turns.isEmpty) {
      conversation.title = value.length > 32
          ? '${value.substring(0, 32)}…'
          : value;
    }
    conversation.turns.add(AiTurn(value, mine: true));
    notifyListeners();
  }

  void addAiAssistantTurn(String text) {
    final value = text.trim();
    if (value.isEmpty) return;
    conversations[activeConv].turns.add(AiTurn(value, mine: false));
    notifyListeners();
  }

  void clearActiveConversation() {
    conversations[activeConv].turns.clear();
    conversations[activeConv].title = 'Yangi suhbat';
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

  /// Replaces only the collections that were actually published by the live
  /// session. Product pages keep their original design, while authenticated
  /// workspaces never have to render seeded showcase records as server data.
  void replaceServerSnapshot({
    List<Student>? students,
    List<Branch>? branches,
    List<Approval>? approvals,
    List<LedgerEntry>? ledger,
    List<Anomaly>? anomalies,
    List<AuditCase>? cases,
    List<ChatThread>? threads,
    List<ManagedGroup>? groups,
    List<DepartmentRecord>? departments,
    List<StaffMember>? staff,
    List<ActivityEvent>? activities,
  }) {
    if (students != null) {
      this.students
        ..clear()
        ..addAll(students);
    }
    if (branches != null) {
      this.branches
        ..clear()
        ..addAll(branches);
    }
    if (approvals != null) {
      this.approvals
        ..clear()
        ..addAll(approvals);
    }
    if (ledger != null) {
      this.ledger
        ..clear()
        ..addAll(ledger);
    }
    if (anomalies != null) {
      this.anomalies
        ..clear()
        ..addAll(anomalies);
    }
    if (cases != null) {
      this.cases
        ..clear()
        ..addAll(cases);
    }
    if (threads != null) {
      this.threads
        ..clear()
        ..addAll(threads);
    }
    if (groups != null) {
      extraGroups
        ..clear()
        ..addAll(groups);
    }
    if (departments != null) {
      this.departments
        ..clear()
        ..addAll(departments);
    }
    if (staff != null) {
      this.staff
        ..clear()
        ..addAll(staff);
    }
    if (activities != null) {
      this.activities
        ..clear()
        ..addAll(activities);
    }
    notifyListeners();
  }

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
    if (name != null) {
      nameOverride = name.trim().isEmpty ? null : name.trim();
    }
    if (title != null) {
      titleOverride = title.trim().isEmpty ? null : title.trim();
    }
    notifyListeners();
  }

  void addStudent(Student student, {required String branch}) {
    students.insert(0, student);
    _log(
      icon: Icons.person_add_alt_1_rounded,
      title: "O'quvchi qo'shildi",
      detail: '${student.name} · $branch · ${student.group}',
      kind: 'student',
    );
  }

  void addGroup(ManagedGroup group) {
    extraGroups.insert(0, group);
    _log(
      icon: Icons.workspaces_rounded,
      title: 'Yangi guruh yaratildi',
      detail: '${group.name} · ${group.branch}',
      kind: 'group',
    );
  }

  void addStaff(StaffMember member) {
    staff.insert(0, member);
    final department = _departmentNamed(member.department);
    department?.history.insert(
      0,
      DepartmentChange(
        icon: Icons.person_add_alt_1_rounded,
        title: 'Xodim qo‘shildi',
        detail: member.fullName,
      ),
    );
    _log(
      icon: Icons.badge_rounded,
      title: 'Xodim qo‘shildi',
      detail: '${member.fullName} · ${member.department}',
      kind: 'staff',
    );
  }

  List<StaffMember> staffForDepartment(DepartmentRecord department) => staff
      .where((member) => member.department == department.name)
      .toList(growable: false);

  List<String> groupsForStaff(StaffMember member) {
    final names = <String>{...member.groups};
    for (final group in extraGroups) {
      if (group.teacher.toLowerCase() == member.fullName.toLowerCase()) {
        names.add(group.name);
      }
    }
    return names.toList(growable: false);
  }

  List<Student> studentsForGroup(String groupName) => students
      .where(
        (student) =>
            student.group.trim().toLowerCase() ==
            groupName.trim().toLowerCase(),
      )
      .toList(growable: false);

  List<LedgerEntry> paymentsForGroup(String groupName, {DateTimeRange? range}) {
    final members = studentsForGroup(
      groupName,
    ).map((student) => student.name.toLowerCase()).toSet();
    return ledger
        .where((entry) {
          if (!entry.inflow) return false;
          final belongs =
              entry.group?.trim().toLowerCase() ==
                  groupName.trim().toLowerCase() ||
              members.contains(entry.studentName.toLowerCase());
          if (!belongs || range == null) return belongs;
          final date = _ledgerDate(entry.date);
          if (date == null) return false;
          final start = DateTime(
            range.start.year,
            range.start.month,
            range.start.day,
          );
          final end = DateTime(
            range.end.year,
            range.end.month,
            range.end.day,
            23,
            59,
            59,
          );
          return !date.isBefore(start) && !date.isAfter(end);
        })
        .toList(growable: false);
  }

  GroupAnalytics analyticsForGroup(String groupName, {DateTimeRange? range}) {
    final groupStudents = studentsForGroup(groupName);
    final payments = paymentsForGroup(groupName, range: range);
    final attendance = groupStudents.isEmpty
        ? 0
        : (groupStudents.fold<int>(
                    0,
                    (sum, student) => sum + student.attendance,
                  ) /
                  groupStudents.length)
              .round();
    return GroupAnalytics(
      studentCount: groupStudents.length,
      averageAttendance: attendance,
      debtorCount: groupStudents.where((student) => student.debt > 0).length,
      debt: groupStudents.fold<num>(0, (sum, student) => sum + student.debt),
      income: payments.fold<num>(0, (sum, entry) => sum + entry.amount),
    );
  }

  List<GroupNote> notesForGroup(String groupName) =>
      groupNotes
          .where((note) => note.groupName == groupName)
          .toList(growable: false)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  void addGroupNote(String groupName, String text) {
    final value = text.trim();
    if (value.isEmpty) return;
    groupNotes.add(
      GroupNote(groupName: groupName, text: value, createdAt: DateTime.now()),
    );
    notifyListeners();
  }

  List<GroupExam> examsForGroup(String groupName) =>
      groupExams
          .where((exam) => exam.groupName == groupName)
          .toList(growable: false)
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

  void addGroupExam(String groupName, String title, DateTime scheduledAt) {
    final value = title.trim();
    if (value.isEmpty) return;
    groupExams.add(
      GroupExam(groupName: groupName, title: value, scheduledAt: scheduledAt),
    );
    notifyListeners();
  }

  void saveGroupDebtReminder(String groupName) {
    groupDebtReminders[groupName] = DateTime.now();
    notifyListeners();
  }

  void togglePinnedGroup(String groupName) {
    pinnedGroups.contains(groupName)
        ? pinnedGroups.remove(groupName)
        : pinnedGroups.add(groupName);
    notifyListeners();
  }

  List<ParentSummary> get parentSummaries {
    final now = DateTime.now();
    return students
        .map((student) {
          final profile = studentProfile(student);
          return ParentSummary(
            fullName: profile.fatherName,
            phone: profile.fatherPhone,
            child: student,
            teacher: _teacherForGroup(student.group),
            educationStarted: profile.enrolled,
            lastCallAt: now.subtract(Duration(days: studentCallDays(student))),
          );
        })
        .toList(growable: false);
  }

  void addDepartment(DepartmentRecord department) {
    departments.add(department);
    for (final username in department.initialStaffUsernames) {
      final index = staff.indexWhere((member) => member.username == username);
      if (index < 0) continue;
      final member = staff[index];
      staff[index] = member.copyWith(department: department.name);
      department.history.insert(
        0,
        DepartmentChange(
          icon: Icons.person_add_alt_1_rounded,
          title: 'Xodim biriktirildi',
          detail: member.fullName,
        ),
      );
    }
    _log(
      icon: Icons.create_new_folder_rounded,
      title: 'Yangi bo‘lim yaratildi',
      detail:
          '${department.name} · ${department.branch} · ${department.manager}',
      kind: 'staff',
    );
  }

  /// Move an employee without losing their profile. The audit entry is added
  /// to both the source and target departments as well as global History.
  void transferStaff(StaffMember member, DepartmentRecord target) {
    final index = staff.indexWhere((item) => item.username == member.username);
    if (index < 0 || member.department == target.name) return;
    final source = _departmentNamed(member.department);
    staff[index] = member.copyWith(department: target.name);
    source?.history.insert(
      0,
      DepartmentChange(
        icon: Icons.arrow_outward_rounded,
        title: 'Xodim ko‘chirildi',
        detail: '${member.fullName} → ${target.name}',
      ),
    );
    target.history.insert(
      0,
      DepartmentChange(
        icon: Icons.arrow_downward_rounded,
        title: 'Xodim qabul qilindi',
        detail: '${member.fullName} · ${member.department}',
      ),
    );
    if (source?.manager == member.fullName) source!.manager = 'Tayinlanmagan';
    _log(
      icon: Icons.swap_horiz_rounded,
      title: 'Xodim bo‘limga ko‘chirildi',
      detail: '${member.fullName} · ${member.department} → ${target.name}',
      kind: 'staff',
    );
  }

  void transferStaffToBranch(StaffMember member, String targetBranch) {
    final branch = targetBranch.trim();
    final index = staff.indexWhere((item) => item.username == member.username);
    if (index < 0 || branch.isEmpty || member.branch == branch) return;
    final source = member.branch;
    staff[index] = member.copyWith(branch: branch);
    _log(
      icon: Icons.swap_horiz_rounded,
      title: 'Xodim filialga ko‘chirildi',
      detail: '${member.fullName} · $source → $branch',
      kind: 'staff',
    );
  }

  void appointDepartmentManager(
    DepartmentRecord department,
    StaffMember member,
  ) {
    if (member.department != department.name) {
      transferStaff(member, department);
    }
    final assigned = staff.firstWhere(
      (item) => item.username == member.username,
      orElse: () => member,
    );
    department.manager = assigned.fullName;
    department.history.insert(
      0,
      DepartmentChange(
        icon: Icons.workspace_premium_rounded,
        title: 'Yangi rahbar tayinlandi',
        detail: assigned.fullName,
      ),
    );
    _log(
      icon: Icons.workspace_premium_rounded,
      title: 'Bo‘lim rahbari yangilandi',
      detail: '${department.name} · ${assigned.fullName}',
      kind: 'staff',
    );
  }

  /// Ends an employee's local employment record. The action uses the store,
  /// not a widget-local list, so it now updates every HR/Department screen.
  void dismissStaff(StaffMember member) {
    final index = staff.indexWhere((item) => item.username == member.username);
    if (index < 0) return;
    staff.removeAt(index);
    final department = _departmentNamed(member.department);
    if (department != null) {
      if (department.manager == member.fullName) {
        department.manager = 'Tayinlanmagan';
      }
      department.history.insert(
        0,
        DepartmentChange(
          icon: Icons.person_remove_rounded,
          title: 'Xodim ishdan bo‘shatildi',
          detail: member.fullName,
        ),
      );
    }
    _log(
      icon: Icons.person_remove_rounded,
      title: 'Xodim ishdan bo‘shatildi',
      detail: '${member.fullName} · ${member.department}',
      kind: 'staff',
    );
  }

  DepartmentRecord? _departmentNamed(String name) {
    for (final department in departments) {
      if (department.name == name) return department;
    }
    return null;
  }

  String _teacherForGroup(String groupName) {
    for (final group in extraGroups) {
      if (group.name.toLowerCase() == groupName.toLowerCase()) {
        return group.teacher;
      }
    }
    for (final member in staff) {
      if (member.groups.any(
        (group) => group.toLowerCase() == groupName.toLowerCase(),
      )) {
        return member.fullName;
      }
    }
    return 'Tayinlanmagan';
  }

  DateTime? _ledgerDate(String value) {
    final direct = DateTime.tryParse(value);
    if (direct != null) return direct;
    final parts = value.split('.');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  void logActivity({
    required IconData icon,
    required String title,
    required String detail,
    required String kind,
  }) => _log(icon: icon, title: title, detail: detail, kind: kind);

  void _log({
    required IconData icon,
    required String title,
    required String detail,
    required String kind,
  }) {
    activities.insert(
      0,
      ActivityEvent(
        icon: icon,
        title: title,
        detail: detail,
        time: 'Hozir',
        kind: kind,
      ),
    );
    notifyListeners();
  }

  // ── Messages: pin & archive (Telegram-style) ───────────────────────────
  final Set<int> pinned = {};
  final Set<int> archived = {};
  final Map<int, Set<int>> pinnedMessages = {};
  void togglePin(int idx) {
    pinned.contains(idx) ? pinned.remove(idx) : pinned.add(idx);
    notifyListeners();
  }

  void toggleArchive(int idx) {
    archived.contains(idx) ? archived.remove(idx) : archived.add(idx);
    pinned.remove(idx);
    notifyListeners();
  }

  void deleteMessage(int threadIdx, int messageIdx) {
    final messages = threads[threadIdx].messages;
    if (messageIdx < 0 || messageIdx >= messages.length) return;
    messages.removeAt(messageIdx);
    final pins = pinnedMessages[threadIdx];
    if (pins != null) {
      pins.remove(messageIdx);
      if (pins.isEmpty) pinnedMessages.remove(threadIdx);
    }
    notifyListeners();
  }

  void toggleMessagePin(int threadIdx, int messageIdx) {
    final pins = pinnedMessages.putIfAbsent(threadIdx, () => <int>{});
    pins.contains(messageIdx) ? pins.remove(messageIdx) : pins.add(messageIdx);
    if (pins.isEmpty) pinnedMessages.remove(threadIdx);
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
    threads: threadsFor(
      role,
    ).map((t) => ChatThread(t, [ChatMsg(t.last, mine: false)])).toList(),
  );

  /// Empty authenticated state used before the first API snapshot arrives.
  /// This prevents a flash of demo people, money or audit events after login.
  factory AppStore.empty(SfRole role) {
    final value = AppStore(
      role: role,
      students: <Student>[],
      branches: <Branch>[],
      approvals: <Approval>[],
      ledger: <LedgerEntry>[],
      anomalies: <Anomaly>[],
      cases: <AuditCase>[],
      threads: <ChatThread>[],
    );
    value
      ..extraGroups.clear()
      ..departments.clear()
      ..staff.clear()
      ..activities.clear();
    return value;
  }

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
    cases.insert(
      0,
      AuditCase(
        id,
        '${a.branch} · ${a.title}',
        a.sev == 'low'
            ? 'low'
            : a.sev == 'med'
            ? 'med'
            : 'high',
        'open',
      ),
    );
    _caseStatus[id] = 'open';
    notifyListeners();
  }

  AuditCase createAuditCase(String title, {String severity = 'med'}) {
    final id = 'C-${(_caseSeq++).toString().padLeft(4, '0')}';
    final auditCase = AuditCase(id, title.trim(), severity, 'open');
    cases.insert(0, auditCase);
    _caseStatus[id] = 'open';
    _log(
      icon: Icons.push_pin_rounded,
      title: 'Yangi audit holati',
      detail: '$id · ${auditCase.title}',
      kind: 'audit',
    );
    return auditCase;
  }

  // ── Messages ──────────────────────────────────────────────────────────
  void sendMessage(int threadIdx, String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    threads[threadIdx].messages.add(ChatMsg(t, mine: true));
    notifyListeners();
  }

  /// Adds an image, video, or recorded voice note to the live local thread.
  void sendAttachment(
    int threadIdx, {
    required ChatMessageKind kind,
    required String path,
    String? label,
    Duration? duration,
  }) {
    assert(kind != ChatMessageKind.text);
    threads[threadIdx].messages.add(
      ChatMsg(
        label ?? '',
        mine: true,
        kind: kind,
        path: path,
        duration: duration,
      ),
    );
    notifyListeners();
  }

  LedgerEntry recordPayment({
    required Student student,
    required String payer,
    required num amount,
    required String channel,
    required String operationNumber,
    String? comment,
  }) {
    final now = DateTime.now();
    final profile = studentProfile(student);
    final entry = LedgerEntry(
      id: 'L-${_seq++}',
      title: "Oylik to'lov",
      who: student.name,
      amount: amount,
      inflow: true,
      kind: "To'lov",
      channel: channel,
      date:
          '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}',
      time:
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      payer: payer.trim(),
      student: student.name,
      group: student.group,
      teacher: _teacherForGroup(student.group),
      branch: profile.branch,
      operationNumber: operationNumber.trim(),
      comment: comment?.trim(),
      status: 'accepted',
    );
    ledger.insert(0, entry);
    _log(
      icon: Icons.payments_rounded,
      title: "Yangi to'lov qabul qilindi",
      detail: '${student.name} · $amount · $channel',
      kind: 'payment',
    );
    return entry;
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
    addAiUserTurn(t);
    addAiAssistantTurn(
      'AI ещё не подключен. Подключите AI/backend в настройках и повторите запрос.',
    );
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
