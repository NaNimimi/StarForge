import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';

import 'api_client.dart';
import 'data.dart';
import 'pages.dart' show roleCanNavigate;
import 'reference_ui.dart';
import 'store.dart' show AppScope;
import 'theme.dart';
import 'widgets.dart';

/// Live, schema-tolerant pages. The deployed OpenAPI document describes its
/// response bodies as generic objects, so these widgets intentionally keep
/// every server field rather than dropping fields through speculative models.

Object? _value(Map<String, dynamic> row, List<String> keys) {
  final wanted = keys.map((key) => key.toLowerCase()).toSet();
  for (final entry in row.entries) {
    if (wanted.contains(entry.key.toLowerCase()) && entry.value != null) {
      return entry.value;
    }
  }
  return null;
}

num? _number(Map<String, dynamic> row, List<String> keys) {
  final value = _value(row, keys);
  if (value is num) return value;
  return num.tryParse('$value'.replaceAll(RegExp(r'[^0-9.\-]'), ''));
}

bool _truthy(Object? value) =>
    value == true ||
    '$value'.toLowerCase() == 'true' ||
    '$value'.toLowerCase() == 'active' ||
    '$value'.toLowerCase() == 'paid';

String _text(Object? value, {String empty = '—'}) {
  if (value == null) return empty;
  if (value is List) return value.isEmpty ? empty : value.map(_text).join(', ');
  if (value is Map) {
    final map = Map<String, dynamic>.from(value);
    return _text(
      _value(map, const ['name', 'title', 'full_name', 'label', 'id']),
      empty: empty,
    );
  }
  final output = '$value'.trim();
  return output.isEmpty ? empty : output;
}

String _title(Map<String, dynamic> row, {String fallback = 'Record'}) => _text(
  _value(row, const [
    'full_name',
    'name',
    'display_name',
    'title',
    'student_name',
    'teacher_name',
    'username',
    'id',
  ]),
  empty: fallback,
);

String _id(Map<String, dynamic> row) => _text(
  _value(row, const ['id', 'pk', 'uuid', 'student_id', 'teacher_id']),
  empty: '',
);

String _searchable(Map<String, dynamic> row) => jsonEncode(row).toLowerCase();

String _liveApiError(ApiException error) => switch (error.status) {
  HttpStatus.forbidden =>
    'Bu bo‘limni ko‘rish uchun rolingizda ruxsat yo‘q (403).',
  HttpStatus.notFound =>
    'Bu bo‘lim backendda hali mavjud emas yoki o‘chirilgan (404).',
  _ => error.message,
};

String _prettyKey(String key) => key
    .replaceAll('_', ' ')
    .replaceAll('-', ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _shortDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.'
    '${value.month.toString().padLeft(2, '0')}.${value.year}';

typedef _ReportSaveResult = ({
  String? path,
  bool cancelled,
  bool privateFallback,
});

const int _livePageSize = 20;

class _PageWindow<T> {
  const _PageWindow({
    required this.items,
    required this.page,
    required this.pages,
    required this.total,
    required this.from,
    required this.to,
  });

  final List<T> items;
  final int page;
  final int pages;
  final int total;
  final int from;
  final int to;
}

_PageWindow<T> _pageWindow<T>(
  List<T> source,
  int requestedPage, {
  int pageSize = _livePageSize,
}) {
  final safeSize = pageSize.clamp(1, 1000);
  final pages = source.isEmpty ? 1 : (source.length / safeSize).ceil();
  final page = requestedPage.clamp(1, pages);
  final start = (page - 1) * safeSize;
  final end = (start + safeSize).clamp(0, source.length);
  return _PageWindow<T>(
    items: source.sublist(start, end),
    page: page,
    pages: pages,
    total: source.length,
    from: source.isEmpty ? 0 : start + 1,
    to: end,
  );
}

class _PaginationControls extends StatelessWidget {
  const _PaginationControls({
    required this.window,
    required this.onPageChanged,
    required this.id,
  });

  final _PageWindow<Object?> window;
  final ValueChanged<int> onPageChanged;
  final String id;

  @override
  Widget build(BuildContext context) {
    if (window.total <= _livePageSize) return const SizedBox.shrink();
    final c = SfTheme.of(context);
    Widget button({
      required String suffix,
      required String tooltip,
      required IconData icon,
      required bool enabled,
      required VoidCallback onPressed,
    }) => SizedBox.square(
      dimension: 44,
      child: IconButton(
        key: ValueKey('pagination-$id-$suffix'),
        tooltip: tooltip,
        onPressed: enabled ? onPressed : null,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        icon: Icon(icon, size: 20),
      ),
    );

    return Semantics(
      container: true,
      label:
          '${window.page}-sahifa, jami ${window.pages} sahifa. '
          '${window.from}–${window.to}, jami ${window.total} yozuv.',
      child: Padding(
        padding: const EdgeInsets.only(top: 7),
        child: Row(
          children: [
            button(
              suffix: 'previous',
              tooltip: 'Oldingi sahifa',
              icon: Icons.chevron_left_rounded,
              enabled: window.page > 1,
              onPressed: () => onPageChanged(window.page - 1),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    '${window.page} / ${window.pages}',
                    style: RefType.mono(
                      size: 12,
                      weight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${window.from}–${window.to} · jami ${window.total}',
                    style: RefType.ui(size: 10.5, color: c.muted),
                  ),
                ],
              ),
            ),
            button(
              suffix: 'next',
              tooltip: 'Keyingi sahifa',
              icon: Icons.chevron_right_rounded,
              enabled: window.page < window.pages,
              onPressed: () => onPageChanged(window.page + 1),
            ),
          ],
        ),
      ),
    );
  }
}

_PageWindow<Object?> _paginationWindow<T>(_PageWindow<T> source) =>
    _PageWindow<Object?>(
      items: source.items,
      page: source.page,
      pages: source.pages,
      total: source.total,
      from: source.from,
      to: source.to,
    );

/// Saves through the platform document picker first. Android's app documents
/// directory is intentionally only a fallback because it is private under
/// scoped storage and is not a user-visible Downloads folder.
Future<_ReportSaveResult> _saveReportBytes({
  required String dialogTitle,
  required String fileName,
  required String extension,
  required Uint8List bytes,
}) async {
  try {
    final path = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [extension],
      bytes: bytes,
    );
    if (path == null) {
      return (path: null, cancelled: true, privateFallback: false);
    }
    return (path: path, cancelled: false, privateFallback: false);
  } catch (_) {
    if (!kIsWeb) {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      return (path: file.path, cancelled: false, privateFallback: true);
    }
    rethrow;
  }
}

class LiveStudentsPage extends StatefulWidget {
  const LiveStudentsPage({super.key});

  @override
  State<LiveStudentsPage> createState() => _LiveStudentsPageState();
}

class _LiveStudentsPageState extends State<LiveStudentsPage> {
  final _search = TextEditingController();
  String _query = '';
  int _filter = 0;
  int _page = 1;
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      await ApiScope.of(context).refresh('students');
      if (mounted) setState(() => _page = 1);
    } on ApiException catch (error) {
      _error = _liveApiError(error);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  bool _matches(Map<String, dynamic> row) {
    if (_query.isNotEmpty && !_searchable(row).contains(_query.toLowerCase())) {
      return false;
    }
    final debt =
        _number(row, const [
          'debt',
          'outstanding',
          'balance_due',
          'amount_due',
        ]) ??
        0;
    final active = _truthy(
      _value(row, const ['is_active', 'active', 'status', 'enrollment_status']),
    );
    return switch (_filter) {
      1 => active,
      2 => debt > 0,
      3 => !active,
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final session = ApiScope.of(context);
    final rows = session.records('students');
    final filtered = rows.where(_matches).toList();
    final page = _pageWindow(filtered, _page);
    return _LiveShell(
      title: 'O‘quvchilar',
      eyebrow: 'LIVE API · ${session.totalFor('students')} O‘QUVCHI',
      subtitle:
          'Backenddagi o‘quvchilar ro‘yxati va to‘liq profil ma’lumotlari',
      loading: _refreshing,
      onRefresh: _refresh,
      body: [
        RefAdaptiveGrid(
          minCellWidth: 150,
          children: [
            RefMetricCard(
              label: 'Jami',
              value: '${rows.length}',
              icon: Icons.groups_rounded,
              tone: RefMetricTone.primary,
            ),
            RefMetricCard(
              label: 'Qarzdor',
              value:
                  '${rows.where((row) => (_number(row, const ['debt', 'outstanding', 'balance_due', 'amount_due']) ?? 0) > 0).length}',
              icon: Icons.account_balance_wallet_outlined,
              tone: RefMetricTone.warning,
            ),
            RefMetricCard(
              label: 'Faol',
              value:
                  '${rows.where((row) => _truthy(_value(row, const ['is_active', 'active', 'status', 'enrollment_status']))).length}',
              icon: Icons.how_to_reg_rounded,
              tone: RefMetricTone.success,
            ),
          ],
        ),
        const SizedBox(height: 16),
        RefSearchField(
          controller: _search,
          hint: 'Ism, ID, guruh yoki istalgan maydon bo‘yicha qidirish',
          onChanged: (value) => setState(() {
            _query = value;
            _page = 1;
          }),
          suffix: _query.isEmpty
              ? null
              : IconButton(
                  onPressed: () => setState(() {
                    _search.clear();
                    _query = '';
                    _page = 1;
                  }),
                  icon: Icon(Icons.close_rounded, color: c.muted),
                ),
        ),
        const SizedBox(height: 10),
        RefSegmentedControl<int>(
          values: const [0, 1, 2, 3],
          selected: _filter,
          labelOf: (value) =>
              const ['Hammasi', 'Faol', 'Qarzdor', 'Nofaol'][value],
          onChanged: (value) => setState(() {
            _filter = value;
            _page = 1;
          }),
        ),
        const SizedBox(height: 20),
        RefSectionHeader(
          title: 'O‘quvchilar ro‘yxati',
          subtitle:
              '${filtered.length} ta mos natija · pastga tortib yangilang',
        ),
        const SizedBox(height: 8),
        if (_error != null) _LiveError(message: _error!, onRetry: _refresh),
        if (_error == null && rows.isEmpty && !_refreshing)
          const _LiveEmpty(
            icon: Icons.groups_outlined,
            message:
                'API o‘quvchi qaytarmadi yoki ushbu rol uchun ruxsat yo‘q.',
          ),
        if (_error == null &&
            rows.isNotEmpty &&
            filtered.isEmpty &&
            !_refreshing)
          const _LiveEmpty(
            icon: Icons.search_off_rounded,
            message: 'Qidiruv va tanlangan filtr bo‘yicha natija topilmadi.',
          ),
        for (var index = 0; index < page.items.length; index++) ...[
          RefStaggeredReveal(
            order: index,
            child: _StudentCard(record: page.items[index]),
          ),
          const SizedBox(height: 9),
        ],
        _PaginationControls(
          id: 'students',
          window: _paginationWindow(page),
          onPageChanged: (value) => setState(() => _page = value),
        ),
      ],
    );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.record});
  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final group = _text(
      _value(record, const ['group_name', 'group', 'cohort_name', 'cohort']),
    );
    final attendance = _number(record, const [
      'attendance',
      'attendance_rate',
      'attendance_percentage',
    ]);
    final debt = _number(record, const [
      'debt',
      'outstanding',
      'balance_due',
      'amount_due',
    ]);
    final status = _text(
      _value(record, const ['status', 'enrollment_status', 'payment_status']),
    );
    return RefPressable(
      onPressed: () => Navigator.of(context).push(
        sfPageRoute(
          LiveRecordDetailPage(
            resource: 'students',
            initial: record,
            title: 'O‘quvchi profili',
            colors: c,
          ),
        ),
      ),
      borderRadius: RefRadius.lg,
      child: RefSurfaceCard(
        padding: const EdgeInsets.all(14),
        elevated: true,
        child: Column(
          children: [
            Row(
              children: [
                SfAvatar(name: _title(record, fallback: 'O‘quvchi'), size: 46),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _title(record, fallback: 'O‘quvchi'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RefType.ui(
                          size: 14,
                          weight: FontWeight.w800,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$group · ${_text(_value(record, const ['branch_name', 'branch', 'student_code', 'id']))}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RefType.ui(size: 11, color: c.muted),
                      ),
                    ],
                  ),
                ),
                RefPill(
                  label: status,
                  tone:
                      _truthy(
                        _value(record, const ['is_active', 'active', 'status']),
                      )
                      ? RefPillTone.success
                      : RefPillTone.neutral,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _MiniField(
                  label: 'DAVOMAT',
                  value: attendance == null
                      ? '—'
                      : '${attendance.toStringAsFixed(attendance % 1 == 0 ? 0 : 1)}%',
                  color: attendance == null
                      ? c.muted
                      : attendance >= 90
                      ? c.success
                      : c.warn,
                ),
                _MiniField(
                  label: 'QARZ',
                  value: debt == null ? '—' : fmtMoneyShort(debt),
                  color: debt == null || debt == 0 ? c.success : c.danger,
                ),
                _MiniField(
                  label: 'MAYDONLAR',
                  value: '${record.length}',
                  color: c.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Live teacher directory. Ratings belong to departments, not teachers.
class LiveTeachersPage extends StatefulWidget {
  const LiveTeachersPage({super.key});

  @override
  State<LiveTeachersPage> createState() => _LiveTeachersPageState();
}

class _LiveTeachersPageState extends State<LiveTeachersPage> {
  final _search = TextEditingController();
  String _query = '';
  int _page = 1;
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      await Future.wait([
        ApiScope.of(context).refresh('teachers'),
        ApiScope.of(context).refresh('groups'),
        ApiScope.of(context).refresh('students'),
      ]);
      if (mounted) setState(() => _page = 1);
    } on ApiException catch (error) {
      _error = _liveApiError(error);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ApiScope.of(context);
    final teachers = session.records('teachers');
    final groups = session.records('groups');
    final rows = teachers
        .where(
          (row) =>
              _query.isEmpty || _searchable(row).contains(_query.toLowerCase()),
        )
        .toList();
    final page = _pageWindow(rows, _page);
    return _LiveShell(
      title: 'O‘qituvchilar',
      eyebrow: 'LIVE API · ${session.totalFor('teachers')} O‘QITUVCHI',
      subtitle: 'O‘qituvchi profili, biriktirilgan guruhlar va o‘quvchilar',
      loading: _refreshing,
      onRefresh: _refresh,
      body: [
        RefAdaptiveGrid(
          minCellWidth: 150,
          children: [
            RefMetricCard(
              label: 'O‘qituvchilar',
              value: '${teachers.length}',
              icon: Icons.school_rounded,
              tone: RefMetricTone.primary,
            ),
            RefMetricCard(
              label: 'Guruhlar',
              value: '${groups.length}',
              icon: Icons.workspaces_rounded,
              tone: RefMetricTone.accent,
            ),
            RefMetricCard(
              label: 'O‘quvchilar',
              value: '${session.records('students').length}',
              icon: Icons.groups_rounded,
              tone: RefMetricTone.success,
            ),
          ],
        ),
        const SizedBox(height: 16),
        RefSearchField(
          controller: _search,
          hint: 'O‘qituvchi yoki istalgan maydonni qidirish',
          onChanged: (value) => setState(() {
            _query = value;
            _page = 1;
          }),
        ),
        const SizedBox(height: 20),
        RefSectionHeader(
          title: 'O‘qituvchilar ro‘yxati',
          subtitle: '${rows.length} ta o‘qituvchi · guruh va profil bilan',
        ),
        const SizedBox(height: 8),
        if (_error != null) _LiveError(message: _error!, onRetry: _refresh),
        if (_error == null && teachers.isEmpty && !_refreshing)
          const _LiveEmpty(
            icon: Icons.school_outlined,
            message:
                'API o‘qituvchilar ro‘yxatini qaytarmadi yoki ruxsat yo‘q.',
          ),
        if (_error == null &&
            teachers.isNotEmpty &&
            rows.isEmpty &&
            !_refreshing)
          const _LiveEmpty(
            icon: Icons.search_off_rounded,
            message: 'Qidiruv bo‘yicha o‘qituvchi topilmadi.',
          ),
        for (var index = 0; index < page.items.length; index++) ...[
          RefStaggeredReveal(
            order: index,
            child: _TeacherCard(record: page.items[index]),
          ),
          const SizedBox(height: 9),
        ],
        _PaginationControls(
          id: 'teachers',
          window: _paginationWindow(page),
          onPageChanged: (value) => setState(() => _page = value),
        ),
      ],
    );
  }
}

class _TeacherCard extends StatelessWidget {
  const _TeacherCard({required this.record});
  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final session = ApiScope.of(context);
    final groups = session.groupsForTeacher(record);
    final students = session.studentsForTeacher(record);
    final status = _text(
      _value(record, const ['status', 'employment_status', 'is_active']),
    );
    return RefPressable(
      onPressed: () => Navigator.of(context).push(
        sfPageRoute(
          LiveRecordDetailPage(
            resource: 'teachers',
            initial: record,
            title: 'O‘qituvchi profili',
            colors: c,
          ),
        ),
      ),
      borderRadius: RefRadius.lg,
      child: RefSurfaceCard(
        padding: const EdgeInsets.all(14),
        elevated: true,
        child: Column(
          children: [
            Row(
              children: [
                SfAvatar(
                  name: _title(record, fallback: 'O‘qituvchi'),
                  size: 42,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _title(record, fallback: 'O‘qituvchi'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RefType.ui(
                          size: 14,
                          weight: FontWeight.w800,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _text(
                          _value(record, const [
                            'subject',
                            'department_name',
                            'department',
                            'branch_name',
                            'branch',
                          ]),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RefType.ui(size: 11, color: c.muted),
                      ),
                    ],
                  ),
                ),
                RefPill(label: status, tone: RefPillTone.success),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _MiniField(
                  label: 'GURUHLAR',
                  value: '${groups.length}',
                  color: c.primary,
                ),
                _MiniField(
                  label: 'O‘QUVCHILAR',
                  value: '${students.length}',
                  color: c.success,
                ),
                _MiniField(
                  label: 'MAYDONLAR',
                  value: '${record.length}',
                  color: c.accentInk,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class LiveEmployeesPage extends StatefulWidget {
  const LiveEmployeesPage({super.key});
  @override
  State<LiveEmployeesPage> createState() => _LiveEmployeesPageState();
}

class _LiveEmployeesPageState extends State<LiveEmployeesPage> {
  final _search = TextEditingController();
  String _query = '';
  int _page = 1;
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      await ApiScope.of(context).refresh('staff');
      if (mounted) setState(() => _page = 1);
    } on ApiException catch (error) {
      _error = _liveApiError(error);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ApiScope.of(context);
    final all = session.records('staff');
    final rows = all
        .where(
          (row) =>
              _query.isEmpty || _searchable(row).contains(_query.toLowerCase()),
        )
        .toList();
    final page = _pageWindow(rows, _page);
    return _LiveShell(
      title: 'Xodimlar',
      eyebrow: 'LIVE API · ${session.totalFor('staff')} XODIM',
      subtitle: 'Backenddagi xodimlar va barcha mavjud maydonlar',
      loading: _refreshing,
      onRefresh: _refresh,
      body: [
        RefSearchField(
          controller: _search,
          hint: 'Xodim, bo‘lim yoki istalgan maydonni qidirish',
          onChanged: (value) => setState(() {
            _query = value;
            _page = 1;
          }),
        ),
        const SizedBox(height: 20),
        RefSectionHeader(
          title: 'Xodimlar ro‘yxati',
          subtitle: '${rows.length} ta mos natija',
        ),
        const SizedBox(height: 8),
        if (_error != null) _LiveError(message: _error!, onRetry: _refresh),
        if (_error == null && all.isEmpty && !_refreshing)
          const _LiveEmpty(
            icon: Icons.badge_outlined,
            message: 'API xodimlar ro‘yxatini qaytarmadi yoki ruxsat yo‘q.',
          ),
        if (_error == null && all.isNotEmpty && rows.isEmpty && !_refreshing)
          const _LiveEmpty(
            icon: Icons.search_off_rounded,
            message: 'Qidiruv bo‘yicha xodim topilmadi.',
          ),
        for (var index = 0; index < page.items.length; index++) ...[
          RefStaggeredReveal(
            order: index,
            child: _EmployeeCard(record: page.items[index]),
          ),
          const SizedBox(height: 9),
        ],
        _PaginationControls(
          id: 'staff',
          window: _paginationWindow(page),
          onPageChanged: (value) => setState(() => _page = value),
        ),
      ],
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({required this.record});
  final Map<String, dynamic> record;
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return RefStatusTile(
      icon: Icons.badge_rounded,
      title: _title(record, fallback: 'Xodim'),
      subtitle:
          '${_text(_value(record, const ['position', 'job_title', 'role', 'department_name', 'department']))} · ${_text(_value(record, const ['branch_name', 'branch', 'email', 'phone']))}',
      tone: RefMetricTone.primary,
      trailing: Text(
        '${record.length}',
        style: RefType.mono(size: 12, weight: FontWeight.w700, color: c.muted),
      ),
      onTap: () => Navigator.of(context).push(
        sfPageRoute(
          LiveRecordDetailPage(
            resource: 'staff',
            initial: record,
            title: 'Xodim profili',
            colors: c,
          ),
        ),
      ),
    );
  }
}

class LiveAttendanceAnalyticsPage extends StatefulWidget {
  const LiveAttendanceAnalyticsPage({super.key});
  @override
  State<LiveAttendanceAnalyticsPage> createState() =>
      _LiveAttendanceAnalyticsPageState();
}

class _LiveAttendanceAnalyticsPageState
    extends State<LiveAttendanceAnalyticsPage> {
  int _page = 1;
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      await Future.wait([
        ApiScope.of(context).refresh('attendanceSummary'),
        ApiScope.of(context).refresh('attendanceRecords'),
      ]);
      if (mounted) setState(() => _page = 1);
    } on ApiException catch (error) {
      _error = _liveApiError(error);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ApiScope.of(context);
    final summary = session.document('attendanceSummary');
    final summaryMap = summary is Map
        ? Map<String, dynamic>.from(summary)
        : const <String, dynamic>{};
    final records = session.records('attendanceRecords');
    final page = _pageWindow(records, _page);
    final statuses = <String, int>{};
    for (final record in records) {
      final status = _text(
        _value(record, const ['status', 'attendance_status', 'state']),
      );
      statuses[status] = (statuses[status] ?? 0) + 1;
    }
    return _LiveShell(
      title: 'Davomat tahlili',
      eyebrow: 'LIVE API · ${session.totalFor('attendanceRecords')} QAYD',
      subtitle: 'Attendance summary va barcha qaytgan davomat yozuvlari',
      loading: _refreshing,
      onRefresh: _refresh,
      body: [
        if (_error != null) _LiveError(message: _error!, onRetry: _refresh),
        if (_error == null && summaryMap.isNotEmpty)
          _ObjectSection(title: 'Attendance summary', value: summaryMap),
        if (summaryMap.isNotEmpty) const SizedBox(height: 14),
        if (statuses.isNotEmpty) ...[
          RefSectionHeader(
            title: 'Statuslar taqsimoti',
            subtitle: 'API qaytargan ${records.length} qayd',
          ),
          const SizedBox(height: 8),
          RefSurfaceCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                for (final entry in statuses.entries)
                  _StatusBar(
                    label: entry.key,
                    value: entry.value,
                    total: records.length,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        RefSectionHeader(
          title: 'Davomat yozuvlari',
          subtitle: 'Pastga tortib yangilang',
        ),
        const SizedBox(height: 8),
        if (_error == null && records.isEmpty && !_refreshing)
          const _LiveEmpty(
            icon: Icons.how_to_reg_outlined,
            message:
                'API davomat qaydlarini yoki summary ma’lumotini qaytarmadi.',
          ),
        for (var index = 0; index < page.items.length; index++) ...[
          RefStaggeredReveal(
            order: index,
            child: _AttendanceRecordCard(record: page.items[index]),
          ),
          const SizedBox(height: 9),
        ],
        _PaginationControls(
          id: 'attendance',
          window: _paginationWindow(page),
          onPageChanged: (value) => setState(() => _page = value),
        ),
      ],
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.label,
    required this.value,
    required this.total,
  });
  final String label;
  final int value;
  final int total;
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final color =
        label.toLowerCase().contains('present') ||
            label.toLowerCase().contains('qatnash')
        ? c.success
        : label.toLowerCase().contains('late')
        ? c.warn
        : c.danger;
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RefType.ui(
                size: 11.5,
                weight: FontWeight.w700,
                color: c.ink2,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : value / total,
                minHeight: 8,
                backgroundColor: c.surface2,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Text(
            '$value',
            style: RefType.mono(
              size: 11,
              weight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceRecordCard extends StatelessWidget {
  const _AttendanceRecordCard({required this.record});
  final Map<String, dynamic> record;
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final status = _text(
      _value(record, const ['status', 'attendance_status', 'state']),
    );
    return RefStatusTile(
      icon: Icons.how_to_reg_rounded,
      title: _text(
        _value(record, const [
          'student_name',
          'student',
          'name',
          'learner_name',
        ]),
        empty: 'Davomat yozuvi',
      ),
      subtitle:
          '${_text(_value(record, const ['lesson_name', 'lesson', 'cohort_name', 'cohort']))} · ${_text(_value(record, const ['date', 'created_at', 'lesson_date']))}',
      tone: status.toLowerCase().contains('present')
          ? RefMetricTone.success
          : RefMetricTone.warning,
      trailing: RefPill(
        label: status,
        tone: status.toLowerCase().contains('present')
            ? RefPillTone.success
            : RefPillTone.warning,
      ),
      onTap: () => Navigator.of(context).push(
        sfPageRoute(
          LiveRecordDetailPage(
            resource: 'attendanceRecords',
            initial: record,
            title: 'Davomat yozuvi',
            colors: c,
          ),
        ),
      ),
    );
  }
}

class LiveFinancePage extends StatefulWidget {
  const LiveFinancePage({super.key});
  @override
  State<LiveFinancePage> createState() => _LiveFinancePageState();
}

class _LiveFinancePageState extends State<LiveFinancePage> {
  int _page = 1;
  bool _refreshing = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      await Future.wait([
        ApiScope.of(context).refresh('payments'),
        ApiScope.of(context).refresh('invoices'),
        ApiScope.of(context).refresh('expenses'),
        ApiScope.of(context).refresh('financeOutstanding'),
      ]);
      if (mounted) setState(() => _page = 1);
    } on ApiException catch (error) {
      _error = _liveApiError(error);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ApiScope.of(context);
    final payments = session.records('payments');
    final page = _pageWindow(payments, _page);
    final income = payments.fold<num>(
      0,
      (sum, row) =>
          sum + (_number(row, const ['amount', 'paid_amount', 'total']) ?? 0),
    );
    final outstanding = session.document('financeOutstanding');
    return _LiveShell(
      title: 'Daromad va moliya',
      eyebrow: 'LIVE API · ${session.totalFor('payments')} TO‘LOV',
      subtitle: 'To‘lovlar, invoice, xarajat va qarzdorlik ma’lumotlari',
      loading: _refreshing,
      onRefresh: _refresh,
      body: [
        RefAdaptiveGrid(
          minCellWidth: 150,
          children: [
            RefMetricCard(
              label: 'To‘lovlar',
              value: fmtMoneyMln(income),
              icon: Icons.payments_rounded,
              tone: RefMetricTone.success,
            ),
            RefMetricCard(
              label: 'Invoice',
              value: '${session.records('invoices').length}',
              icon: Icons.receipt_long_rounded,
              tone: RefMetricTone.primary,
            ),
            RefMetricCard(
              label: 'Xarajat',
              value: '${session.records('expenses').length}',
              icon: Icons.money_off_rounded,
              tone: RefMetricTone.danger,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_error != null) _LiveError(message: _error!, onRetry: _refresh),
        if (outstanding != null)
          _ObjectSection(
            title: 'Qarzdorlik · finance/outstanding',
            value: outstanding,
          ),
        if (outstanding != null) const SizedBox(height: 20),
        RefSectionHeader(
          title: 'So‘nggi to‘lovlar',
          subtitle: '${payments.length} ta backend yozuvi',
        ),
        const SizedBox(height: 8),
        if (_error == null && payments.isEmpty && !_refreshing)
          const _LiveEmpty(
            icon: Icons.payments_outlined,
            message: 'API to‘lov ma’lumotlarini qaytarmadi yoki ruxsat yo‘q.',
          ),
        for (var index = 0; index < page.items.length; index++) ...[
          RefStaggeredReveal(
            order: index,
            child: _PaymentLiveCard(record: page.items[index]),
          ),
          const SizedBox(height: 9),
        ],
        _PaginationControls(
          id: 'payments',
          window: _paginationWindow(page),
          onPageChanged: (value) => setState(() => _page = value),
        ),
      ],
    );
  }
}

class _PaymentLiveCard extends StatelessWidget {
  const _PaymentLiveCard({required this.record});
  final Map<String, dynamic> record;
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final amount = _number(record, const ['amount', 'paid_amount', 'total']);
    final status = _text(
      _value(record, const ['status', 'payment_status', 'state']),
    );
    final normalized = status.toLowerCase();
    final failed =
        normalized.contains('cancel') ||
        normalized.contains('fail') ||
        normalized.contains('reject');
    final pending =
        normalized.contains('pending') ||
        normalized.contains('process') ||
        normalized.contains('wait');
    final tone = failed
        ? RefMetricTone.danger
        : pending
        ? RefMetricTone.warning
        : RefMetricTone.success;
    final pillTone = failed
        ? RefPillTone.danger
        : pending
        ? RefPillTone.warning
        : RefPillTone.success;
    final amountColor = failed
        ? c.danger
        : pending
        ? c.warn
        : c.success;
    final id = _id(record);
    final title = _title(record, fallback: 'To‘lov');
    return Semantics(
      key: ValueKey('live-payment-${id.isEmpty ? title : id}'),
      button: true,
      label: '$title. To‘lov tafsilotini ochish',
      child: RefStatusTile(
        icon: Icons.payments_rounded,
        title: title,
        subtitle:
            '${_text(_value(record, const ['student_name', 'student', 'payer_name', 'payer']))} · ${_text(_value(record, const ['method_name', 'method', 'provider', 'created_at', 'date']))}',
        tone: tone,
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              amount == null ? '—' : fmtMoneyShort(amount),
              style: RefType.mono(
                size: 12,
                weight: FontWeight.w800,
                color: amountColor,
              ),
            ),
            const SizedBox(height: 4),
            RefPill(label: status, tone: pillTone),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          sfPageRoute(
            LiveRecordDetailPage(
              resource: 'payments',
              initial: record,
              title: 'To‘lov tafsiloti',
              colors: c,
            ),
          ),
        ),
      ),
    );
  }
}

class LiveRecordDetailPage extends StatefulWidget {
  const LiveRecordDetailPage({
    super.key,
    required this.resource,
    required this.initial,
    required this.title,
    required this.colors,
  });
  final String resource;
  final Map<String, dynamic> initial;
  final String title;
  final SfColors colors;
  @override
  State<LiveRecordDetailPage> createState() => _LiveRecordDetailPageState();
}

/// Reusable real-data view for the remaining REST collections. It keeps the
/// established card/list presentation while exposing all fields on tap, so a
/// logged-in user never sees a mock list for an endpoint that exists.
class LiveCollectionPage extends StatefulWidget {
  const LiveCollectionPage({
    super.key,
    required this.resource,
    required this.title,
    required this.icon,
  });

  final String resource;
  final String title;
  final IconData icon;

  @override
  State<LiveCollectionPage> createState() => _LiveCollectionPageState();
}

class _LiveCollectionPageState extends State<LiveCollectionPage> {
  final _search = TextEditingController();
  String _query = '';
  int _page = 1;
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      await ApiScope.of(context).refresh(widget.resource);
      if (mounted) setState(() => _page = 1);
    } on ApiException catch (error) {
      _error = _liveApiError(error);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ApiScope.of(context);
    final all = widget.resource == 'departments'
        ? session.departmentRanking
        : session.records(widget.resource);
    final rows = all
        .where(
          (row) =>
              _query.isEmpty || _searchable(row).contains(_query.toLowerCase()),
        )
        .toList();
    final page = _pageWindow(rows, _page);
    final storedError = session.resourceError(widget.resource);
    final displayedError =
        _error ?? (storedError == null ? null : _liveApiError(storedError));
    return _LiveShell(
      title: widget.title,
      eyebrow: 'LIVE API · ${session.totalFor(widget.resource)} YOZUV',
      subtitle:
          'Backend ma’lumotlari · qidirish, tortib yangilash va tafsilotlar',
      loading: _refreshing,
      onRefresh: _refresh,
      body: [
        RefSearchField(
          controller: _search,
          hint: 'Istalgan maydon bo‘yicha qidirish',
          onChanged: (value) => setState(() {
            _query = value;
            _page = 1;
          }),
        ),
        const SizedBox(height: 20),
        RefSectionHeader(
          title: widget.title,
          subtitle: '${rows.length} ta mos backend yozuvi',
        ),
        const SizedBox(height: 8),
        if (displayedError != null)
          _LiveError(message: displayedError, onRetry: _refresh),
        if (displayedError == null && all.isEmpty && !_refreshing)
          _LiveEmpty(
            icon: widget.icon,
            message: 'API yozuv qaytarmadi yoki ushbu rol uchun ruxsat yo‘q.',
          ),
        if (displayedError == null &&
            all.isNotEmpty &&
            rows.isEmpty &&
            !_refreshing)
          _LiveEmpty(
            icon: Icons.search_off_rounded,
            message: 'Qidiruv bo‘yicha mos backend yozuvi topilmadi.',
          ),
        for (var index = 0; index < page.items.length; index++) ...[
          RefStaggeredReveal(
            order: index,
            child: _GenericRecordCard(
              record: page.items[index],
              title: widget.title,
              resource: widget.resource,
              icon: widget.icon,
            ),
          ),
          const SizedBox(height: 9),
        ],
        _PaginationControls(
          id: widget.resource,
          window: _paginationWindow(page),
          onPageChanged: (value) => setState(() => _page = value),
        ),
      ],
    );
  }
}

class _GenericRecordCard extends StatelessWidget {
  const _GenericRecordCard({
    required this.record,
    required this.title,
    required this.resource,
    required this.icon,
  });
  final Map<String, dynamic> record;
  final String title;
  final String resource;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final sub = switch (resource) {
      'groups' =>
        '${_text(_value(record, const ['teacher_name', 'teacher', 'instructor_name', 'instructor']))} · '
            '${_text(_value(record, const ['student_count', 'students_count', 'members_count']), empty: '0')} o‘quvchi',
      'parents' =>
        '${_text(_value(record, const ['child_name', 'student_name', 'child', 'student']))} · '
            '${_text(_value(record, const ['teacher_name', 'teacher']))} · '
            '${_text(_value(record, const ['education_started', 'start_date', 'enrolled_at', 'created_at']))} · '
            '${_text(_value(record, const ['last_call_at', 'last_call', 'contacted_at']))}',
      'departments' =>
        '${_text(_value(record, const ['branch_name', 'branch']))} · '
            '★ ${_text(_value(record, const ['rating', 'score', 'performance_score']))}',
      _ => _text(
        _value(record, const [
          'status',
          'branch_name',
          'branch',
          'department_name',
          'department',
          'created_at',
          'date',
        ]),
      ),
    };
    final recordTitle = _title(record, fallback: title);
    final id = _id(record);
    return Semantics(
      key: ValueKey('live-$resource-${id.isEmpty ? recordTitle : id}'),
      button: true,
      label: '$recordTitle. Tafsilotlarni ochish',
      child: RefStatusTile(
        icon: icon,
        title: recordTitle,
        subtitle: '$sub · ${record.length} fields',
        tone: RefMetricTone.primary,
        trailing: Icon(Icons.chevron_right_rounded, color: c.muted),
        onTap: () => Navigator.of(context).push(
          sfPageRoute(
            LiveRecordDetailPage(
              resource: resource,
              initial: record,
              title: resource == 'payments' ? 'To‘lov tafsiloti' : title,
              colors: c,
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveRecordDetailPageState extends State<LiveRecordDetailPage> {
  late Map<String, dynamic> _record = widget.initial;
  bool _loading = false;
  bool _groupExporting = false;
  String? _error;
  DateTimeRange? _groupRange;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final id = _id(_record);
    if (id.isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await ApiScope.of(context).detail(widget.resource, id);
      if (detail != null && mounted) setState(() => _record = detail);
    } on ApiException catch (error) {
      _error = _liveApiError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickGroupRange() async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange:
          _groupRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month - 1, now.day),
            end: now,
          ),
      helpText: 'Guruh tarixining davri',
      cancelText: 'Bekor qilish',
      confirmText: 'Qo‘llash',
    );
    if (selected != null && mounted) setState(() => _groupRange = selected);
  }

  Future<void> _chooseGroupExport(ApiGroupSnapshot group) async {
    if (_groupExporting) return;
    final format = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Guruh hisobotini yuklab olish'),
              subtitle: Text('Joriy sana filtri hisobotga qo‘llanadi'),
            ),
            ListTile(
              leading: const Icon(Icons.grid_on_rounded),
              title: const Text('CSV hisobot'),
              onTap: () => Navigator.of(sheetContext).pop('csv'),
            ),
            ListTile(
              leading: const Icon(Icons.code_rounded),
              title: const Text('HTML hisobot'),
              onTap: () => Navigator.of(sheetContext).pop('html'),
            ),
          ],
        ),
      ),
    );
    if (format == null || !mounted) return;
    await _exportGroupReport(group, format);
  }

  Future<void> _exportGroupReport(ApiGroupSnapshot group, String format) async {
    if (_groupExporting) return;
    setState(() => _groupExporting = true);
    final generated = DateTime.now();
    final groupName = _title(group.group, fallback: 'Guruh');
    final rangeLabel = _groupRange == null
        ? 'Barcha davr'
        : '${_shortDate(_groupRange!.start)} — ${_shortDate(_groupRange!.end)}';
    final summary = <List<String>>[
      ['Guruh', groupName],
      ['Davr', rangeLabel],
      ['O‘quvchilar', '${group.analytics['student_count'] ?? 0}'],
      ['Davomat', '${group.analytics['attendance_percent'] ?? 0}%'],
      ['Qarzdorlar', '${group.analytics['debtor_count'] ?? 0}'],
      ['Qarzdorlik', '${group.analytics['debt'] ?? 0}'],
      ['Tasdiqlangan daromad', '${group.analytics['income'] ?? 0}'],
      ['To‘lov yozuvlari', '${group.payments.length}'],
      ['Imtihonlar', '${group.exams.length}'],
      ['Yaratildi', generated.toIso8601String()],
    ];
    String csvCell(Object? value) =>
        '"${'$value'.replaceAll('"', '""').replaceAll('\r', ' ').replaceAll('\n', ' ')}"';
    String csvRecords(String section, Iterable<Map<String, dynamic>> records) =>
        records
            .map(
              (record) => [
                section,
                apiRecordId(record),
                _title(record, fallback: 'Yozuv'),
                jsonEncode(record),
              ].map(csvCell).join(','),
            )
            .join('\n');
    final csv = [
      'Ko‘rsatkich,Qiymat',
      ...summary.map((row) => row.map(csvCell).join(',')),
      '',
      'Bo‘lim,ID,Nomi,Barcha maydonlar',
      csvRecords('O‘quvchi', group.students),
      csvRecords('Davomat', group.attendance),
      csvRecords('To‘lov', group.payments),
      csvRecords('O‘zgarish', group.changes),
      csvRecords('Imtihon', group.exams),
    ].where((line) => line.isNotEmpty).join('\n');
    final escape = const HtmlEscape();
    String htmlRows(Iterable<Map<String, dynamic>> records) => records
        .map(
          (record) =>
              '<tr><td>${escape.convert(apiRecordId(record))}</td>'
              '<td>${escape.convert(_title(record, fallback: 'Yozuv'))}</td>'
              '<td><pre>${escape.convert(jsonEncode(record))}</pre></td></tr>',
        )
        .join();
    String section(String title, Iterable<Map<String, dynamic>> records) =>
        '<h2>${escape.convert(title)}</h2><table border="1" cellspacing="0" '
        'cellpadding="5"><tr><th>ID</th><th>Nomi</th><th>Maydonlar</th></tr>'
        '${htmlRows(records)}</table>';
    final html =
        '<!doctype html><html><head><meta charset="utf-8">'
        '<title>${escape.convert(groupName)}</title></head><body>'
        '<h1>${escape.convert(groupName)}</h1>'
        '<table border="1" cellspacing="0" cellpadding="5">'
        '${summary.map((row) => '<tr><th>${escape.convert(row[0])}</th>'
            '<td>${escape.convert(row[1])}</td></tr>').join()}</table>'
        '${section('O‘quvchilar', group.students)}'
        '${section('Davomat', group.attendance)}'
        '${section('To‘lovlar', group.payments)}'
        '${section('O‘zgarishlar', group.changes)}'
        '${section('Imtihonlar', group.exams)}'
        '</body></html>';
    final safeName = groupName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final extension = format == 'csv' ? 'csv' : 'html';
    final fileName =
        'group_${safeName.isEmpty ? 'report' : safeName}_'
        '${generated.millisecondsSinceEpoch}.$extension';
    try {
      final result = await _saveReportBytes(
        dialogTitle: 'Guruh hisobotini saqlash',
        fileName: fileName,
        extension: extension,
        bytes: Uint8List.fromList(
          utf8.encode(format == 'csv' ? '\uFEFF$csv' : html),
        ),
      );
      if (!mounted) return;
      if (result.cancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hisobotni saqlash bekor qilindi')),
        );
      } else {
        final suffix = result.privateFallback
            ? ' · ilovaning ichki papkasiga saqlandi'
            : '';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$fileName saqlandi$suffix')));
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hisobotni saqlab bo‘lmadi: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _groupExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final session = ApiScope.of(context);
    final payment = widget.resource == 'payments'
        ? ApiPaymentDetails(_record)
        : null;
    final group = widget.resource == 'groups'
        ? session.groupSnapshot(
            _record,
            range: _groupRange == null
                ? null
                : ApiDateRange(from: _groupRange!.start, to: _groupRange!.end),
          )
        : null;
    final teacherGroups = widget.resource == 'teachers'
        ? session.groupsForTeacher(_record)
        : const <Map<String, dynamic>>[];
    final teacherStudents = widget.resource == 'teachers'
        ? session.studentsForTeacher(_record)
        : const <Map<String, dynamic>>[];
    final children = widget.resource == 'parents'
        ? session.childrenForParent(_record)
        : const <Map<String, dynamic>>[];
    final departmentStaff = widget.resource == 'departments'
        ? session.staffForDepartment(_record)
        : const <Map<String, dynamic>>[];
    return SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: _LiveShell(
            title: widget.title,
            eyebrow: 'LIVE API · ${widget.resource}',
            subtitle: 'Backend qaytargan barcha maydonlar',
            loading: _loading,
            onRefresh: _refresh,
            leading: RefIconAction(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Ortga',
              onPressed: () => Navigator.of(context).pop(),
            ),
            body: [
              if (_error != null)
                _LiveError(message: _error!, onRetry: _refresh),
              if (payment != null)
                _ObjectSection(
                  title: 'To‘lov ma’lumotlari',
                  value: {
                    'Sana': payment.date,
                    'Vaqt': payment.time,
                    'Summa': payment.amount == null
                        ? '—'
                        : fmtMoney(payment.amount!),
                    'To‘lov usuli': payment.method,
                    'Kim to‘ladi': payment.payer,
                    'O‘quvchi': payment.student,
                    'Guruh': payment.group,
                    'O‘qituvchi': payment.teacher,
                    'Filial': payment.branch,
                    'Operatsiya raqami': payment.operationNumber,
                    'Izoh': payment.comment,
                    'Holat': payment.status,
                  },
                ),
              if (payment != null) const SizedBox(height: 12),
              if (group != null) ...[
                KeyedSubtree(
                  key: const ValueKey('live-group-report-export'),
                  child: RefButton(
                    label: _groupExporting
                        ? 'Hisobot tayyorlanmoqda…'
                        : 'Guruh hisobotini yuklab olish',
                    kind: RefButtonKind.soft,
                    leading: Icons.file_download_outlined,
                    block: true,
                    onPressed: _groupExporting
                        ? null
                        : () => _chooseGroupExport(group),
                  ),
                ),
                const SizedBox(height: 10),
                RefButton(
                  label: _groupRange == null
                      ? 'Sana oralig‘i: barcha davr'
                      : '${_shortDate(_groupRange!.start)} — '
                            '${_shortDate(_groupRange!.end)}',
                  kind: RefButtonKind.ghost,
                  leading: Icons.date_range_rounded,
                  block: true,
                  onPressed: _pickGroupRange,
                ),
                const SizedBox(height: 12),
                _ObjectSection(
                  title: 'CEO analitika',
                  value: {
                    'O‘quvchilar': group.analytics['student_count'],
                    'Davomat': '${group.analytics['attendance_percent']}%',
                    'Qarzdorlar': group.analytics['debtor_count'],
                    'Qarzdorlik': fmtMoney(group.analytics['debt'] ?? 0),
                    'Guruh daromadi': fmtMoney(group.analytics['income'] ?? 0),
                    'To‘lovlar': group.analytics['payment_count'],
                    'Imtihonlar': group.analytics['exam_count'],
                  },
                ),
                const SizedBox(height: 12),
                _ObjectSection(
                  title: 'O‘quvchilar',
                  value: {
                    'Jami': group.students.length,
                    'Ro‘yxat': group.students
                        .map((row) => _title(row, fallback: 'O‘quvchi'))
                        .toList(),
                  },
                ),
                const SizedBox(height: 12),
                _ObjectSection(
                  title: 'Davomat tarixi',
                  value: {
                    'Jami': group.attendance.length,
                    'Yozuvlar': group.attendance,
                  },
                ),
                const SizedBox(height: 12),
                _ObjectSection(
                  title: 'To‘lovlar tarixi',
                  value: {
                    'Jami': group.payments.length,
                    'Yozuvlar': group.payments,
                  },
                ),
                const SizedBox(height: 12),
                _ObjectSection(
                  title: 'O‘zgarishlar tarixi',
                  value: {
                    'Jami': group.changes.length,
                    'Yozuvlar': group.changes,
                  },
                ),
                const SizedBox(height: 12),
                _ObjectSection(
                  title: 'Imtihonlar',
                  value: {'Jami': group.exams.length, 'Yozuvlar': group.exams},
                ),
                const SizedBox(height: 12),
              ],
              if (widget.resource == 'teachers') ...[
                _ObjectSection(
                  title: 'Biriktirilgan guruhlar',
                  value: {
                    'Jami': teacherGroups.length,
                    'Ro‘yxat': teacherGroups
                        .map((row) => _title(row, fallback: 'Guruh'))
                        .toList(),
                  },
                ),
                const SizedBox(height: 12),
                _ObjectSection(
                  title: 'O‘quvchilar',
                  value: {
                    'Jami': teacherStudents.length,
                    'Ro‘yxat': teacherStudents
                        .map((row) => _title(row, fallback: 'O‘quvchi'))
                        .toList(),
                  },
                ),
                const SizedBox(height: 12),
              ],
              if (widget.resource == 'parents') ...[
                _ObjectSection(
                  title: 'Farzandlar',
                  value: {
                    'Jami': children.length,
                    'Ro‘yxat': children
                        .map((row) => _title(row, fallback: 'O‘quvchi'))
                        .toList(),
                  },
                ),
                const SizedBox(height: 12),
              ],
              if (widget.resource == 'departments') ...[
                _ObjectSection(
                  title: 'Bo‘lim reytingi va jamoa',
                  value: {
                    'Reyting':
                        _number(_record, const [
                          'rating',
                          'score',
                          'performance_score',
                        ]) ??
                        '—',
                    'Xodimlar': departmentStaff.length,
                    'Jamoa': departmentStaff
                        .map((row) => _title(row, fallback: 'Xodim'))
                        .toList(),
                  },
                ),
                const SizedBox(height: 12),
              ],
              _ObjectSection(
                title: payment == null
                    ? _title(_record, fallback: widget.title)
                    : 'Backendning asl maydonlari',
                value: _record,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveShell extends StatelessWidget {
  const _LiveShell({
    required this.title,
    required this.eyebrow,
    required this.subtitle,
    required this.loading,
    required this.onRefresh,
    required this.body,
    this.leading,
  });
  final String title;
  final String eyebrow;
  final String subtitle;
  final bool loading;
  final Future<void> Function() onRefresh;
  final List<Widget> body;
  final Widget? leading;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      RefLargeHeader(
        title: title,
        eyebrow: eyebrow,
        subtitle: subtitle,
        leading: leading,
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (loading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              ...body,
            ],
          ),
        ),
      ),
    ],
  );
}

class _MiniField extends StatelessWidget {
  const _MiniField({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: RefRadius.md,
        ),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RefType.mono(
                  size: 11.5,
                  weight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RefType.eyebrow(size: 7.5, color: c.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ObjectSection extends StatelessWidget {
  const _ObjectSection({required this.title, required this.value});
  final String title;
  final Object value;
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final rows = <MapEntry<String, Object?>>[];
    if (value is Map) {
      for (final entry in (value as Map).entries) {
        rows.add(MapEntry('${entry.key}', entry.value));
      }
    } else {
      rows.add(MapEntry('value', value));
    }
    return RefSurfaceCard(
      padding: EdgeInsets.zero,
      elevated: true,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: RefType.ui(
                      size: 14,
                      weight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
                ),
                Text(
                  '${rows.length} fields',
                  style: RefType.mono(size: 10, color: c.muted),
                ),
              ],
            ),
          ),
          for (var index = 0; index < rows.length; index++)
            _ObjectRow(entry: rows[index], last: index == rows.length - 1),
        ],
      ),
    );
  }
}

class _ObjectRow extends StatelessWidget {
  const _ObjectRow({required this.entry, required this.last});
  final MapEntry<String, Object?> entry;
  final bool last;
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final complex = entry.value is Map || entry.value is List;
    final output = complex
        ? const JsonEncoder.withIndent('  ').convert(entry.value)
        : _text(entry.value);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: c.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _prettyKey(entry.key),
              style: RefType.eyebrow(size: 9, color: c.muted),
            ),
            const SizedBox(height: 4),
            SelectableText(
              output,
              style: complex
                  ? RefType.mono(size: 10.5, color: c.ink2, height: 1.35)
                  : RefType.ui(
                      size: 12.5,
                      weight: FontWeight.w600,
                      color: c.ink,
                      height: 1.35,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveError extends StatelessWidget {
  const _LiveError({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RefSurfaceCard(
        padding: const EdgeInsets.all(14),
        color: c.dangerSoft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'API xatosi',
              style: RefType.ui(
                size: 13.5,
                weight: FontWeight.w800,
                color: c.danger,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              message,
              style: RefType.ui(size: 12, color: c.danger, height: 1.35),
            ),
            const SizedBox(height: 10),
            RefButton(
              label: 'Qayta urinish',
              kind: RefButtonKind.ghost,
              leading: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveEmpty extends StatelessWidget {
  const _LiveEmpty({required this.icon, required this.message});
  final IconData icon;
  final String message;
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return RefSurfaceCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, color: c.muted, size: 30),
          const SizedBox(height: 9),
          Text(
            message,
            textAlign: TextAlign.center,
            style: RefType.ui(size: 12.5, color: c.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ── Live revenue report ────────────────────────────────────────────────

enum _ReportPeriod { week, month, quarter, year }

enum _ReportExportFormat { pdf, csv, html }

extension on _ReportExportFormat {
  String get label => switch (this) {
    _ReportExportFormat.pdf => 'PDF',
    _ReportExportFormat.csv => 'CSV',
    _ReportExportFormat.html => 'HTML',
  };

  String get extension => switch (this) {
    _ReportExportFormat.pdf => 'pdf',
    _ReportExportFormat.csv => 'csv',
    _ReportExportFormat.html => 'html',
  };

  IconData get icon => switch (this) {
    _ReportExportFormat.pdf => Icons.picture_as_pdf_rounded,
    _ReportExportFormat.csv => Icons.grid_on_rounded,
    _ReportExportFormat.html => Icons.code_rounded,
  };
}

/// The full income report intentionally derives every number and graph point
/// from the live finance endpoints.  It has no generated trend or fallback
/// metric: an unavailable endpoint is shown as such instead of being masked by
/// local demo data.
class LiveRevenueReportPage extends StatefulWidget {
  const LiveRevenueReportPage({super.key});

  @override
  State<LiveRevenueReportPage> createState() => _LiveRevenueReportPageState();
}

class _LiveRevenueReportPageState extends State<LiveRevenueReportPage> {
  _ReportPeriod _period = _ReportPeriod.month;
  bool _refreshing = false;
  bool _exporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      await Future.wait([
        ApiScope.of(context).refresh('payments'),
        ApiScope.of(context).refresh('invoices'),
        ApiScope.of(context).refresh('expenses'),
        ApiScope.of(context).refresh('refunds'),
        ApiScope.of(context).refresh('financeOutstanding'),
      ]);
    } on ApiException catch (error) {
      _error = _liveApiError(error);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  DateTime _monthsBefore(DateTime value, int months) {
    final targetMonth = DateTime(value.year, value.month - months);
    final lastDay = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
    final day = value.day > lastDay ? lastDay : value.day;
    return DateTime(targetMonth.year, targetMonth.month, day);
  }

  ({DateTime from, DateTime to}) _periodRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final from = switch (_period) {
      // Inclusive today + six previous calendar days is exactly seven days.
      _ReportPeriod.week => today.subtract(const Duration(days: 6)),
      _ReportPeriod.month => _monthsBefore(today, 1),
      _ReportPeriod.quarter => _monthsBefore(today, 3),
      _ReportPeriod.year => _monthsBefore(today, 12),
    };
    return (from: from, to: now);
  }

  DateTime? _recordDate(Map<String, dynamic> record) {
    return apiRecordDate(record)?.toLocal();
  }

  List<Map<String, dynamic>> _inPeriod(
    List<Map<String, dynamic>> records, {
    bool settledPaymentsOnly = false,
  }) {
    final range = _periodRange();
    return records
        .where((record) {
          if (settledPaymentsOnly && !apiPaymentCountsAsSettled(record)) {
            return false;
          }
          // Undated and future records cannot honestly be assigned to a selected
          // reporting period. They remain available in the source collection.
          return apiRecordWithinInclusivePeriod(
            record,
            from: range.from,
            to: range.to,
          );
        })
        .toList(growable: false);
  }

  String _periodLabel() => switch (_period) {
    _ReportPeriod.week => '7 kun',
    _ReportPeriod.month => '1 oy',
    _ReportPeriod.quarter => '3 oy',
    _ReportPeriod.year => '12 oy',
  };

  String _dateLabel(DateTime? value) {
    if (value == null) return 'Sana ko‘rsatilmagan';
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }

  num _amount(Map<String, dynamic> row) =>
      _number(row, const ['amount', 'paid_amount', 'total', 'sum', 'value']) ??
      0;

  Future<void> _chooseExport(
    List<Map<String, dynamic>> payments,
    List<Map<String, dynamic>> invoices,
    List<Map<String, dynamic>> expenses,
    List<Map<String, dynamic>> refunds,
  ) async {
    final c = SfTheme.of(context);
    final format = await showModalBottomSheet<_ReportExportFormat>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SfTheme(
        colors: c,
        child: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Hisobot formatini tanlang',
                  style: RefType.ui(
                    size: 18,
                    weight: FontWeight.w800,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Format tanlangandan keyin fayl yaratiladi.',
                  style: RefType.ui(size: 12, color: c.muted),
                ),
                const SizedBox(height: 12),
                for (final option in _ReportExportFormat.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: RefRadius.md,
                      child: InkWell(
                        borderRadius: RefRadius.md,
                        onTap: () => Navigator.of(sheetContext).pop(option),
                        child: Ink(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: c.surface2,
                            borderRadius: RefRadius.md,
                            border: Border.all(color: c.border),
                          ),
                          child: Row(
                            children: [
                              Icon(option.icon, color: c.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  option.label,
                                  style: RefType.ui(
                                    size: 14,
                                    weight: FontWeight.w800,
                                    color: c.ink,
                                  ),
                                ),
                              ),
                              Icon(Icons.arrow_forward_rounded, color: c.muted),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (format == null || !mounted) return;
    await _export(format, payments, invoices, expenses, refunds);
  }

  List<List<String>> _exportRows(
    List<Map<String, dynamic>> payments,
    List<Map<String, dynamic>> invoices,
    List<Map<String, dynamic>> expenses,
    List<Map<String, dynamic>> refunds,
  ) {
    final rows = <List<String>>[
      ['Bo‘lim', 'ID', 'Nomi', 'Summa', 'Status', 'Sana', 'Barcha maydonlar'],
    ];
    void add(String section, List<Map<String, dynamic>> source) {
      for (final record in source) {
        rows.add([
          section,
          _id(record),
          _title(record, fallback: section),
          _amount(record).toString(),
          _text(_value(record, const ['status', 'state', 'payment_status'])),
          _dateLabel(_recordDate(record)),
          jsonEncode(record),
        ]);
      }
    }

    add('To‘lov', payments);
    add('Invoice', invoices);
    add('Xarajat', expenses);
    add('Refund', refunds);
    return rows;
  }

  String _csv(List<List<String>> rows) => rows
      .map(
        (row) => row.map((cell) => '"${cell.replaceAll('"', '""')}"').join(','),
      )
      .join('\n');

  String _htmlReport(List<List<String>> rows, String title) {
    final escape = const HtmlEscape();
    final table = rows
        .map(
          (row) =>
              '<tr>${row.map((cell) => '<td>${escape.convert(cell)}</td>').join()}</tr>',
        )
        .join();
    return '<!doctype html><html><meta charset="utf-8"><body>'
        '<h1>${escape.convert(title)}</h1><p>Davr: ${escape.convert(_periodLabel())}</p>'
        '<table border="1" cellspacing="0" cellpadding="5">$table</table></body></html>';
  }

  List<int> _pdfReport(List<List<String>> rows) {
    final lines = <String>[
      'StarForge EDU — Daromad hisoboti',
      'Davr: ${_periodLabel()}',
      ...rows
          .skip(1)
          .take(38)
          .map(
            (row) =>
                '${row[0]} | ${row[2]} | ${row[3]} | ${row[4]} | ${row[5]}',
          ),
    ].map((line) => line.replaceAll(RegExp(r'[^\x20-\x7E]'), '?')).toList();
    final content = StringBuffer('BT\n/F1 9 Tf\n50 790 Td\n');
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index]
          .replaceAll('\\', '\\\\')
          .replaceAll('(', '\\(')
          .replaceAll(')', '\\)');
      content.write('($line) Tj\n');
      if (index != lines.length - 1) content.write('0 -16 Td\n');
    }
    content.write('ET');
    final objects = <String>[
      '1 0 obj<< /Type /Catalog /Pages 2 0 R >>endobj',
      '2 0 obj<< /Type /Pages /Kids [3 0 R] /Count 1 >>endobj',
      '3 0 obj<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>endobj',
      '4 0 obj<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>endobj',
      '5 0 obj<< /Length ${content.length} >>stream\n$content\nendstream\nendobj',
    ];
    final buffer = StringBuffer('%PDF-1.4\n');
    final offsets = <int>[0];
    for (final object in objects) {
      offsets.add(buffer.length);
      buffer.write('$object\n');
    }
    final xref = buffer.length;
    buffer.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
    for (final offset in offsets.skip(1)) {
      buffer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
    }
    buffer.write(
      'trailer<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF',
    );
    return latin1.encode(buffer.toString());
  }

  Future<void> _export(
    _ReportExportFormat format,
    List<Map<String, dynamic>> payments,
    List<Map<String, dynamic>> invoices,
    List<Map<String, dynamic>> expenses,
    List<Map<String, dynamic>> refunds,
  ) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final rows = _exportRows(payments, invoices, expenses, refunds);
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'starforge_daromad_$stamp.${format.extension}';
      final bytes = Uint8List.fromList(switch (format) {
        _ReportExportFormat.csv => utf8.encode('\uFEFF${_csv(rows)}'),
        _ReportExportFormat.html => utf8.encode(
          _htmlReport(rows, 'StarForge EDU Revenue Report'),
        ),
        _ReportExportFormat.pdf => _pdfReport(rows),
      });
      final result = await _saveReportBytes(
        dialogTitle: '${format.label} hisobotini saqlash',
        fileName: fileName,
        extension: format.extension,
        bytes: bytes,
      );
      if (!mounted) return;
      if (result.cancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hisobotni saqlash bekor qilindi')),
        );
        return;
      }
      final suffix = result.privateFallback
          ? ' · ilovaning ichki papkasiga saqlandi'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${format.label} hisobot saqlandi$suffix')),
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hisobotni saqlab bo‘lmadi: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ApiScope.of(context);
    final payments = _inPeriod(
      session.records('payments'),
      settledPaymentsOnly: true,
    );
    final invoices = _inPeriod(session.records('invoices'));
    final expenses = _inPeriod(session.records('expenses'));
    final refunds = _inPeriod(session.records('refunds'));
    final income = payments.fold<num>(
      0,
      (sum, record) => sum + _amount(record),
    );
    final outflow = expenses.fold<num>(
      0,
      (sum, record) => sum + _amount(record),
    );
    final returned = refunds.fold<num>(
      0,
      (sum, record) => sum + _amount(record),
    );
    return _LiveShell(
      title: 'Daromad hisoboti',
      eyebrow: 'LIVE API · ${_periodLabel().toUpperCase()}',
      subtitle: 'To‘lovlar, xarajatlar, statistika, grafika va eksport',
      loading: _refreshing,
      onRefresh: _refresh,
      body: [
        RefSegmentedControl<_ReportPeriod>(
          values: _ReportPeriod.values,
          selected: _period,
          labelOf: (value) => switch (value) {
            _ReportPeriod.week => '7 kun',
            _ReportPeriod.month => 'Oy',
            _ReportPeriod.quarter => '3 oy',
            _ReportPeriod.year => 'Yil',
          },
          onChanged: (value) => setState(() => _period = value),
        ),
        const SizedBox(height: 12),
        RefButton(
          label: _exporting
              ? 'Hisobot tayyorlanmoqda…'
              : 'Hisobotni eksport qilish',
          leading: Icons.file_download_outlined,
          onPressed: _exporting
              ? null
              : () => _chooseExport(payments, invoices, expenses, refunds),
        ),
        const SizedBox(height: 16),
        RefAdaptiveGrid(
          minCellWidth: 150,
          children: [
            RefMetricCard(
              label: 'Daromad',
              value: fmtMoneyMln(income),
              icon: Icons.trending_up_rounded,
              tone: RefMetricTone.success,
              detail: '${payments.length} to‘lov',
            ),
            RefMetricCard(
              label: 'Xarajat',
              value: fmtMoneyMln(outflow),
              icon: Icons.trending_down_rounded,
              tone: RefMetricTone.danger,
              detail: '${expenses.length} yozuv',
            ),
            RefMetricCard(
              label: 'Qaytarish',
              value: fmtMoneyMln(returned),
              icon: Icons.reply_all_rounded,
              tone: RefMetricTone.warning,
              detail: '${refunds.length} yozuv',
            ),
            RefMetricCard(
              label: 'Sof oqim',
              value: fmtMoneyMln(income - outflow - returned),
              icon: Icons.account_balance_wallet_rounded,
              tone: RefMetricTone.primary,
              detail: '${invoices.length} invoice',
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (_error != null) _LiveError(message: _error!, onRetry: _refresh),
        _LiveRevenueChart(
          payments: payments,
          recordDate: _recordDate,
          amount: _amount,
        ),
        const SizedBox(height: 20),
        if (session.document('financeOutstanding') != null) ...[
          _ObjectSection(
            title: 'Qarzdorlik · finance/outstanding',
            value: session.document('financeOutstanding'),
          ),
          const SizedBox(height: 20),
        ],
        _LiveReportRecords(
          title: 'To‘lovlar',
          resource: 'payments',
          icon: Icons.payments_rounded,
          records: payments,
          empty: 'Bu davr uchun API to‘lov qaytarmadi.',
        ),
        const SizedBox(height: 20),
        _LiveReportRecords(
          title: 'Xarajatlar',
          resource: 'expenses',
          icon: Icons.money_off_rounded,
          records: expenses,
          empty: 'Bu davr uchun API xarajat qaytarmadi.',
        ),
        const SizedBox(height: 20),
        _LiveReportRecords(
          title: 'Invoice va qaytarishlar',
          resource: 'invoices',
          icon: Icons.receipt_long_rounded,
          records: [...invoices, ...refunds],
          empty: 'Bu davr uchun invoice yoki qaytarish topilmadi.',
        ),
      ],
    );
  }
}

class _LiveRevenueChart extends StatelessWidget {
  const _LiveRevenueChart({
    required this.payments,
    required this.recordDate,
    required this.amount,
  });
  final List<Map<String, dynamic>> payments;
  final DateTime? Function(Map<String, dynamic>) recordDate;
  final num Function(Map<String, dynamic>) amount;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final grouped = <String, num>{};
    for (final payment in payments) {
      final date = recordDate(payment);
      final key = date == null
          ? 'Sana yo‘q'
          : '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
      grouped[key] = (grouped[key] ?? 0) + amount(payment);
    }
    final entries = grouped.entries.toList(growable: false);
    return RefSurfaceCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RefSectionHeader(
            title: 'Daromad grafigi',
            subtitle: 'To‘lov endpointidan haqiqiy yig‘indi',
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 200,
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      'Grafik uchun to‘lov ma’lumoti yo‘q',
                      style: RefType.ui(size: 12, color: c.muted),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY:
                          entries
                              .map((entry) => entry.value.toDouble())
                              .reduce((a, b) => a > b ? a : b) *
                          1.15,
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) =>
                            FlLine(color: c.border, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 26,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 ||
                                  index >= entries.length ||
                                  value != index) {
                                return const SizedBox.shrink();
                              }
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                child: Text(
                                  entries[index].key,
                                  style: RefType.mono(size: 8, color: c.muted),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var index = 0; index < entries.length; index++)
                          BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: entries[index].value.toDouble(),
                                color: c.success,
                                width: entries.length > 12 ? 8 : 14,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(5),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LiveReportRecords extends StatefulWidget {
  const _LiveReportRecords({
    required this.title,
    required this.resource,
    required this.icon,
    required this.records,
    required this.empty,
  });
  final String title;
  final String resource;
  final IconData icon;
  final List<Map<String, dynamic>> records;
  final String empty;

  @override
  State<_LiveReportRecords> createState() => _LiveReportRecordsState();
}

class _LiveReportRecordsState extends State<_LiveReportRecords> {
  int _page = 1;

  @override
  void didUpdateWidget(covariant _LiveReportRecords oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.records, widget.records) ||
        oldWidget.records.length != widget.records.length) {
      _page = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _pageWindow(widget.records, _page);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RefSectionHeader(
          title: widget.title,
          subtitle: '${widget.records.length} ta API yozuvi',
        ),
        const SizedBox(height: 8),
        if (widget.records.isEmpty)
          _LiveEmpty(icon: widget.icon, message: widget.empty)
        else
          for (final record in page.items) ...[
            _GenericRecordCard(
              record: record,
              title: widget.title,
              resource: widget.resource,
              icon: widget.icon,
            ),
            const SizedBox(height: 8),
          ],
        _PaginationControls(
          id: 'report-${widget.resource}',
          window: _paginationWindow(page),
          onPageChanged: (value) => setState(() => _page = value),
        ),
      ],
    );
  }
}

// ── Live notifications ────────────────────────────────────────────────

class LiveNotificationsPage extends StatefulWidget {
  const LiveNotificationsPage({super.key, this.onNavigate});
  final ValueChanged<String>? onNavigate;

  @override
  State<LiveNotificationsPage> createState() => _LiveNotificationsPageState();
}

class _LiveNotificationsPageState extends State<LiveNotificationsPage> {
  int _page = 1;
  bool _refreshing = false;
  bool _unreadOnly = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      await Future.wait([
        ApiScope.of(context).refresh('notifications'),
        ApiScope.of(context).refresh('unreadNotifications'),
      ]);
      if (mounted) setState(() => _page = 1);
    } on ApiException catch (error) {
      _error = _liveApiError(error);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  bool _isRead(Map<String, dynamic> record) {
    final value = _value(record, const [
      'is_read',
      'read',
      'read_at',
      'status',
    ]);
    if (value is bool) return value;
    final text = '$value'.toLowerCase();
    return text == 'read' ||
        text == 'seen' ||
        text == 'true' ||
        value != null && _value(record, const ['read_at']) != null;
  }

  String? _destination(Map<String, dynamic> record, SfRole role) {
    String? allowed(Iterable<String> candidates) {
      for (final route in candidates) {
        if (roleCanNavigate(role, route)) return route;
      }
      return null;
    }

    final explicit = _text(
      _value(record, const ['route', 'target', 'section']),
      empty: '',
    ).replaceFirst(RegExp(r'^/+'), '');
    if (explicit.isNotEmpty && roleCanNavigate(role, explicit)) {
      return explicit;
    }
    final source = [
      _value(record, const [
        'route',
        'target',
        'section',
        'entity_type',
        'type',
        'category',
      ]),
      _value(record, const ['title', 'message', 'body']),
    ].join(' ').toLowerCase();
    if (source.contains('student') ||
        source.contains('o‘quv') ||
        source.contains("o'quv")) {
      return allowed(const ['students']);
    }
    if (source.contains('attendance') || source.contains('davomat')) {
      return allowed(const ['attendance']);
    }
    if (source.contains('payment') ||
        source.contains('invoice') ||
        source.contains('to‘lov') ||
        source.contains("to'lov") ||
        source.contains('finance') ||
        source.contains('daromad')) {
      return allowed(const ['payments', 'finance', 'report']);
    }
    if (source.contains('anomal') ||
        source.contains('risk') ||
        source.contains('signal')) {
      return allowed(const ['anomalies', 'cases']);
    }
    if (source.contains('group') || source.contains('guruh')) {
      return allowed(const ['groups']);
    }
    if (source.contains('parent') || source.contains('ota-ona')) {
      return allowed(const ['parents', 'students']);
    }
    if (source.contains('teacher') ||
        source.contains('o‘qit') ||
        source.contains("o'qit")) {
      return allowed(const ['teachers']);
    }
    if (source.contains('staff') ||
        source.contains('employee') ||
        source.contains('xodim')) {
      return allowed(const ['employees', 'hr', 'teachers']);
    }
    if (source.contains('branch') || source.contains('filial')) {
      return allowed(const ['branches', 'comparison']);
    }
    if (source.contains('approval') || source.contains('tasdiq')) {
      return allowed(const ['approvals']);
    }
    if (source.contains('message') ||
        source.contains('thread') ||
        source.contains('xabar')) {
      return allowed(const ['messages']);
    }
    return null;
  }

  Future<void> _open(Map<String, dynamic> record) async {
    final id = _id(record);
    if (!_isRead(record) && id.isNotEmpty) {
      try {
        await ApiScope.of(context).action(
          'POST',
          '/api/v1/notifications/$id/read/',
          refreshResources: const ['notifications', 'unreadNotifications'],
        );
      } on ApiException catch (error) {
        if (mounted) setState(() => _error = _liveApiError(error));
        return;
      }
    }
    if (!mounted) return;
    final route = _destination(record, AppScope.of(context).role);
    if (route != null && widget.onNavigate != null) {
      widget.onNavigate!(route);
      return;
    }
    final c = SfTheme.of(context);
    Navigator.of(context).push(
      sfPageRoute(
        LiveRecordDetailPage(
          resource: 'notifications',
          initial: record,
          title: 'Bildirishnoma',
          colors: c,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ApiScope.of(context);
    final all = session.records('notifications');
    final unreadTotal = all.where((record) => !_isRead(record)).length;
    final filtered = _unreadOnly
        ? all.where((record) => !_isRead(record)).toList(growable: false)
        : all;
    final page = _pageWindow(filtered, _page);
    final unread = page.items
        .where((record) => !_isRead(record))
        .toList(growable: false);
    final read = page.items.where(_isRead).toList(growable: false);
    return _LiveShell(
      title: 'Bildirishnomalar',
      eyebrow: 'LIVE API · ${session.totalFor('notifications')} BILDIRISHNOMA',
      subtitle: '$unreadTotal ta yangi · tegib kerakli bo‘limga o‘ting',
      loading: _refreshing,
      onRefresh: _refresh,
      body: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment<bool>(
              value: true,
              label: Text('Новые'),
              icon: Icon(Icons.mark_email_unread_outlined),
            ),
            ButtonSegment<bool>(
              value: false,
              label: Text('История'),
              icon: Icon(Icons.history_rounded),
            ),
          ],
          selected: {_unreadOnly},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => setState(() {
            _unreadOnly = selection.first;
            _page = 1;
          }),
        ),
        const SizedBox(height: 12),
        if (_error != null) _LiveError(message: _error!, onRetry: _refresh),
        if (all.isEmpty && !_refreshing)
          const _LiveEmpty(
            icon: Icons.notifications_off_outlined,
            message: 'API bildirishnoma qaytarmadi yoki ruxsat yo‘q.',
          ),
        if (all.isNotEmpty && filtered.isEmpty && !_refreshing)
          const _LiveEmpty(
            icon: Icons.done_all_rounded,
            message:
                'Yangi bildirishnoma yo‘q. O‘qilganlari tarixda saqlanadi.',
          ),
        if (unread.isNotEmpty) ...[
          RefSectionHeader(
            title: 'O‘qilmagan',
            subtitle: '${unread.length} ta yangi',
          ),
          const SizedBox(height: 8),
          for (final record in unread) ...[
            _LiveNotificationCard(
              record: record,
              unread: true,
              onTap: () => _open(record),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
        ],
        if (!_unreadOnly && read.isNotEmpty) ...[
          RefSectionHeader(
            title: 'O‘qilgan',
            subtitle: '${read.length} ta bildirishnoma',
          ),
          const SizedBox(height: 8),
          for (final record in read) ...[
            _LiveNotificationCard(
              record: record,
              unread: false,
              onTap: () => _open(record),
            ),
            const SizedBox(height: 8),
          ],
        ],
        _PaginationControls(
          id: 'notifications',
          window: _paginationWindow(page),
          onPageChanged: (value) => setState(() => _page = value),
        ),
      ],
    );
  }
}

class _LiveNotificationCard extends StatelessWidget {
  const _LiveNotificationCard({
    required this.record,
    required this.unread,
    required this.onTap,
  });
  final Map<String, dynamic> record;
  final bool unread;
  final VoidCallback onTap;

  IconData _icon(String type) {
    if (type.contains('payment') || type.contains('finance')) {
      return Icons.payments_rounded;
    }
    if (type.contains('attendance')) {
      return Icons.how_to_reg_rounded;
    }
    if (type.contains('teacher')) {
      return Icons.workspace_premium_rounded;
    }
    if (type.contains('student')) {
      return Icons.groups_rounded;
    }
    if (type.contains('approval')) {
      return Icons.task_alt_rounded;
    }
    if (type.contains('message')) {
      return Icons.chat_bubble_rounded;
    }
    return Icons.notifications_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final type = _text(
      _value(record, const ['type', 'category', 'event_type', 'kind']),
      empty: 'Umumiy',
    );
    final time = _text(
      _value(record, const ['created_at', 'sent_at', 'timestamp', 'date']),
      empty: 'Vaqt ko‘rsatilmagan',
    );
    return RefPressable(
      onPressed: onTap,
      borderRadius: RefRadius.lg,
      child: RefSurfaceCard(
        padding: const EdgeInsets.all(14),
        color: unread ? c.primarySoft : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: c.primary.withValues(alpha: .13),
                borderRadius: RefRadius.md,
              ),
              child: SizedBox(
                width: 42,
                height: 42,
                child: Icon(_icon(type.toLowerCase()), color: c.primary),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _text(
                            record['title'] ??
                                record['subject'] ??
                                record['heading'] ??
                                record['name'] ??
                                record['id'],
                            empty: 'Bildirishnoma',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: RefType.ui(
                            size: 13.5,
                            weight: FontWeight.w800,
                            color: c.ink,
                          ),
                        ),
                      ),
                      if (unread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: c.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _text(
                      _value(record, const [
                        'message',
                        'body',
                        'description',
                        'content',
                      ]),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: RefType.ui(size: 11.5, color: c.muted, height: 1.35),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      RefPill(label: type, tone: RefPillTone.primary),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          time,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: RefType.ui(size: 10, color: c.muted2),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: c.muted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
