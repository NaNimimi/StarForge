import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';

import 'api_catalog.dart';
import 'api_client.dart';
import 'api_data_view.dart';
import 'data.dart';
import 'i18n.dart';
import 'pages.dart' show roleCanNavigate;
import 'reference_ui.dart';
import 'store.dart' show AppScope;
import 'theme.dart';
import 'widgets.dart';

/// Live, schema-tolerant pages. The deployed OpenAPI document describes its
/// response bodies as generic objects, so these widgets intentionally keep
/// every server field rather than dropping fields through speculative models.

String? _apiTagForResource(String resource) {
  final path = kApiResources[resource];
  if (path == null) return null;
  return kPublishedApiOperations
      .where((operation) => operation.path == path)
      .map((operation) => operation.tag)
      .firstOrNull;
}

bool _canMutateResource(BuildContext context, String resource) {
  final store = context
      .dependOnInheritedWidgetOfExactType<AppScope>()
      ?.notifier;
  if (store?.role == SfRole.audit) return false;
  final tag = _apiTagForResource(resource);
  return tag == null || ApiScope.of(context).hasPermission('$tag:write');
}

Object? _value(Map<String, dynamic> row, List<String> keys) {
  // The caller's key order is semantic priority. API maps often start with
  // `id`; scanning map entries first made cards show an ID even when `name`
  // was explicitly preferred by the presentation layer.
  for (final key in keys) {
    final exact = row[key];
    if (exact != null) return exact;
    final normalized = key.toLowerCase();
    for (final entry in row.entries) {
      if (entry.key.toLowerCase() == normalized && entry.value != null) {
        return entry.value;
      }
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
  final presented = apiPresentationValue(value);
  if (presented == null) return empty;
  if (presented is List) {
    return presented.isEmpty ? empty : presented.map(_text).join(', ');
  }
  if (presented is Map) {
    final map = Map<String, dynamic>.from(presented);
    return _text(
      _value(map, const ['name', 'title', 'full_name', 'label', 'id']),
      empty: empty,
    );
  }
  final output = '$presented'.trim();
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

String _collectionEyebrow(BuildContext context, String resource, int total) {
  final section = switch (resource) {
    'branches' => tx(
      context,
      uz: 'FILIAL TARMOĞI',
      ru: 'СЕТЬ ФИЛИАЛОВ',
      en: 'BRANCH NETWORK',
    ),
    'groups' => tx(
      context,
      uz: 'O‘QUV JARAYONI',
      ru: 'УЧЕБНЫЙ ПРОЦЕСС',
      en: 'LEARNING OPERATIONS',
    ),
    'parents' => tx(
      context,
      uz: 'OTA-ONALAR BILAN ALOQA',
      ru: 'РАБОТА С РОДИТЕЛЯМИ',
      en: 'PARENT RELATIONS',
    ),
    'departments' => tx(
      context,
      uz: 'TASHKILIY TUZILMA',
      ru: 'СТРУКТУРА КОМПАНИИ',
      en: 'ORGANIZATION',
    ),
    'audit' => tx(
      context,
      uz: 'NAZORAT JURNALI',
      ru: 'ЖУРНАЛ КОНТРОЛЯ',
      en: 'CONTROL LOG',
    ),
    'studentRisk' => tx(
      context,
      uz: 'XAVF SIGNALARI',
      ru: 'СИГНАЛЫ РИСКА',
      en: 'RISK SIGNALS',
    ),
    _ => tx(context, uz: 'ISH MAYDONI', ru: 'РАБОЧИЙ РАЗДЕЛ', en: 'WORKSPACE'),
  };
  return '$section · $total';
}

String _collectionSubtitle(BuildContext context, String resource) =>
    switch (resource) {
      'branches' => tx(
        context,
        uz: 'Filiallar holati, sig‘imi va aloqa ma’lumotlari',
        ru: 'Статус, вместимость и контакты каждого филиала',
        en: 'Status, capacity and contacts for every branch',
      ),
      'groups' => tx(
        context,
        uz: 'Guruhlar, o‘quvchilar va qarzdorlik nazorati',
        ru: 'Группы, ученики и контроль задолженности',
        en: 'Groups, students and debt control',
      ),
      'parents' => tx(
        context,
        uz: 'Aloqalar, qo‘ng‘iroqlar va o‘quvchi holati',
        ru: 'Контакты, звонки и состояние обучения ребёнка',
        en: 'Contacts, calls and the child learning status',
      ),
      'departments' => tx(
        context,
        uz: 'Bo‘limlar, rahbarlar va mas’ullar',
        ru: 'Департаменты, руководители и ответственные',
        en: 'Departments, leaders and owners',
      ),
      'audit' => tx(
        context,
        uz: 'Muhim harakatlar va tizimdagi o‘zgarishlar',
        ru: 'Важные действия и изменения в системе',
        en: 'Important actions and system changes',
      ),
      'studentRisk' => tx(
        context,
        uz: 'E’tibor talab qiladigan o‘quvchilar va sabablar',
        ru: 'Ученики, которым требуется внимание, и причины',
        en: 'Students requiring attention and the reasons',
      ),
      _ => tx(
        context,
        uz: 'Dolzarb ma’lumotlar va amallar',
        ru: 'Актуальные данные и доступные действия',
        en: 'Current data and available actions',
      ),
    };

bool _isActiveRecord(Map<String, dynamic> row) {
  final value = _value(row, const ['is_active', 'active']);
  if (value != null) return _truthy(value);
  final status = _text(
    _value(row, const ['status', 'state']),
    empty: '',
  ).toLowerCase();
  return status.isEmpty ||
      status.contains('active') ||
      status.contains('faol') ||
      status.contains('актив');
}

String _liveApiError(ApiException error) => switch (error.status) {
  402 =>
    'Подписка центра приостановлена сервером. Восстановите подписку backend, '
        'затем обновите раздел.',
  HttpStatus.forbidden =>
    'Bu bo‘limni ko‘rish uchun rolingizda ruxsat yo‘q (403).',
  HttpStatus.notFound =>
    'Bu bo‘lim backendda hali mavjud emas yoki o‘chirilgan (404).',
  HttpStatus.tooManyRequests =>
    'Сервер временно ограничил частоту обновлений (429). '
        'Приложение остановило повторные запросы; подождите указанное сервером '
        'время и нажмите «Повторить».',
  _ => error.message,
};

String _shortDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.'
    '${value.month.toString().padLeft(2, '0')}.${value.year}';

Future<Map<String, dynamic>?> _jsonObjectEditor(
  BuildContext context, {
  required String title,
  Map<String, dynamic> initial = const {},
}) async {
  final controller = TextEditingController(
    text: const JsonEncoder.withIndent('  ').convert(initial),
  );
  String? validation;
  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Схема публикует тело как JSON object. Заполните поля, '
                'которые разрешены вашим backend и ролью.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                minLines: 7,
                maxLines: 16,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  labelText: 'JSON',
                  errorText: validation,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              try {
                final decoded = jsonDecode(controller.text);
                if (decoded is! Map) throw const FormatException();
                Navigator.of(context).pop(Map<String, dynamic>.from(decoded));
              } on FormatException {
                setDialogState(
                  () => validation = 'Введите корректный JSON-объект',
                );
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    ),
  );
  Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
  return result;
}

/// Product form for the published branch DTO. Raw JSON is reserved for the
/// separate API diagnostics screen; normal administrators should never have
/// to know serializer field names or accidentally submit read-only fields.
Future<Map<String, dynamic>?> _branchEditor(
  BuildContext context, {
  required String title,
  Map<String, dynamic> initial = const {},
}) async {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController(text: apiText(initial['name']));
  final slug = TextEditingController(text: apiText(initial['slug']));
  final address = TextEditingController(text: apiText(initial['address']));
  final phone = TextEditingController(text: apiText(initial['phone']));
  final timezone = TextEditingController(
    text: apiText(initial['timezone']).isEmpty
        ? 'Asia/Tashkent'
        : apiText(initial['timezone']),
  );
  final maxStudents = TextEditingController(
    text: initial['max_students'] == null ? '' : '${initial['max_students']}',
  );
  final maxTeachers = TextEditingController(
    text: initial['max_teachers'] == null ? '' : '${initial['max_teachers']}',
  );
  var isActive = initial['is_active'] is bool
      ? initial['is_active'] as bool
      : true;

  String? requiredValue(String? value) =>
      value == null || value.trim().isEmpty ? 'Обязательное поле' : null;

  String? positiveInteger(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = int.tryParse(text);
    return parsed == null || parsed < 0
        ? 'Введите целое число не меньше 0'
        : null;
  }

  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 620,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    key: const ValueKey('branch-edit-name'),
                    controller: name,
                    autofocus: true,
                    validator: requiredValue,
                    decoration: const InputDecoration(
                      labelText: 'Название филиала',
                      prefixIcon: Icon(Icons.business_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('branch-edit-slug'),
                    controller: slug,
                    validator: requiredValue,
                    decoration: const InputDecoration(
                      labelText: 'Код (slug)',
                      hintText: 'например, chilanzar',
                      prefixIcon: Icon(Icons.tag_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('branch-edit-address'),
                    controller: address,
                    decoration: const InputDecoration(
                      labelText: 'Адрес',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('branch-edit-phone'),
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Телефон',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('branch-edit-timezone'),
                    controller: timezone,
                    validator: requiredValue,
                    decoration: const InputDecoration(
                      labelText: 'Часовой пояс',
                      prefixIcon: Icon(Icons.schedule_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: const ValueKey('branch-edit-max-students'),
                          controller: maxStudents,
                          validator: positiveInteger,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Лимит учеников',
                            prefixIcon: Icon(Icons.groups_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          key: const ValueKey('branch-edit-max-teachers'),
                          controller: maxTeachers,
                          validator: positiveInteger,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Лимит преподавателей',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    key: const ValueKey('branch-edit-status'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Филиал активен'),
                    subtitle: Text(
                      isActive
                          ? 'Доступен в рабочих процессах'
                          : 'Временно отключён',
                    ),
                    value: isActive,
                    onChanged: (value) =>
                        setDialogState(() => isActive = value),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton.icon(
            key: const ValueKey('branch-edit-save'),
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              final payload = <String, dynamic>{
                'name': name.text.trim(),
                'slug': slug.text.trim(),
                'address': address.text.trim(),
                'phone': phone.text.trim(),
                'timezone': timezone.text.trim(),
                'is_active': isActive,
              };
              final studentLimit = int.tryParse(maxStudents.text.trim());
              final teacherLimit = int.tryParse(maxTeachers.text.trim());
              if (studentLimit != null) {
                payload['max_students'] = studentLimit;
              }
              if (teacherLimit != null) {
                payload['max_teachers'] = teacherLimit;
              }
              Navigator.of(dialogContext).pop(payload);
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('Сохранить'),
          ),
        ],
      ),
    ),
  );

  Future<void>.delayed(const Duration(milliseconds: 400), () {
    name.dispose();
    slug.dispose();
    address.dispose();
    phone.dispose();
    timezone.dispose();
    maxStudents.dispose();
    maxTeachers.dispose();
  });
  return result;
}

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
  return _PageWindow<T>(
    items: List<T>.unmodifiable(source),
    page: 1,
    pages: 1,
    total: source.length,
    from: source.isEmpty ? 0 : 1,
    to: source.length,
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
    return const SizedBox.shrink();
    // Pagination was intentionally removed: API resources are fetched fully
    // and rendered by lazy lists/scroll views, so no records are hidden.
    /*
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
    */
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

String _liveDateLabel(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.'
    '${value.month.toString().padLeft(2, '0')}.${value.year}';

class LiveStudentsPage extends StatefulWidget {
  const LiveStudentsPage({super.key});

  @override
  State<LiveStudentsPage> createState() => _LiveStudentsPageState();
}

class _LiveStudentsPageState extends State<LiveStudentsPage> {
  final _search = TextEditingController();
  String _query = '';
  int _filter = 0;
  DateTimeRange? _enrollmentRange;
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
    final range = _enrollmentRange;
    if (range != null) {
      final enrolledAt = apiDate(
        _value(row, const [
          'education_started',
          'start_date',
          'enrolled_at',
          'enrollment_date',
          'admission_date',
          'joined_at',
          'created_at',
        ]),
      );
      if (enrolledAt == null) return false;
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
      if (enrolledAt.isBefore(start) || enrolledAt.isAfter(end)) return false;
    }
    return switch (_filter) {
      1 => active,
      2 => debt > 0,
      3 => !active,
      _ => true,
    };
  }

  Future<void> _pickEnrollmentRange() async {
    final value = await showRefDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _enrollmentRange,
      title: tx(
        context,
        uz: 'O‘qishni boshlagan sana',
        ru: 'Дата начала обучения',
        en: 'Education start date',
      ),
    );
    if (value == null || !mounted) return;
    setState(() {
      _enrollmentRange = value;
      _page = 1;
    });
  }

  Future<void> _openFilters() async {
    final c = SfTheme.of(context);
    var selected = _filter;
    final value = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SfTheme(
        colors: c,
        child: StatefulBuilder(
          builder: (context, updateSheet) => SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RefSectionHeader(
                    title: tx(
                      context,
                      uz: 'O‘quvchi filtrlari',
                      ru: 'Фильтры учеников',
                      en: 'Student filters',
                    ),
                    subtitle: tx(
                      context,
                      uz: 'Ro‘yxat holatini tanlang',
                      ru: 'Выберите статус списка',
                      en: 'Choose a list status',
                    ),
                    trailing: IconButton(
                      tooltip: tx(
                        context,
                        uz: 'Yopish',
                        ru: 'Закрыть',
                        en: 'Close',
                      ),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in <({int value, String label})>[
                        (value: 0, label: tr(context, 'f_all')),
                        (value: 1, label: tr(context, 'status_active')),
                        (value: 2, label: tr(context, 'f_debtor')),
                        (
                          value: 3,
                          label: tx(
                            context,
                            uz: 'Nofaol',
                            ru: 'Неактивные',
                            en: 'Inactive',
                          ),
                        ),
                      ])
                        FilterChip(
                          selected: selected == option.value,
                          label: Text(option.label),
                          onSelected: (_) =>
                              updateSheet(() => selected = option.value),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const ValueKey('live-students-reset-filters'),
                          onPressed: () => updateSheet(() => selected = 0),
                          icon: const Icon(Icons.restart_alt_rounded),
                          label: Text(
                            tx(
                              context,
                              uz: 'Tiklash',
                              ru: 'Сбросить',
                              en: 'Reset',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          key: const ValueKey('live-students-apply-filters'),
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(selected),
                          icon: const Icon(Icons.check_rounded),
                          label: Text(
                            tx(
                              context,
                              uz: 'Qo‘llash',
                              ru: 'Применить',
                              en: 'Apply',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (value == null || !mounted) return;
    setState(() {
      _filter = value;
      _page = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final session = ApiScope.of(context);
    final rows = session.records('students');
    final filtered = rows.where(_matches).toList();
    final page = _pageWindow(filtered, _page);
    return _LiveShell(
      title: tr(context, 'students_title'),
      eyebrow: tx(
        context,
        uz: 'O‘QUVCHILAR BAZASI · ${session.totalFor('students')}',
        ru: 'БАЗА УЧЕНИКОВ · ${session.totalFor('students')}',
        en: 'STUDENT DIRECTORY · ${session.totalFor('students')}',
      ),
      subtitle: tx(
        context,
        uz: 'O‘quvchilar, guruhlar va to‘liq profil ma’lumotlari',
        ru: 'Ученики, группы и полная информация профиля',
        en: 'Students, groups and complete profile details',
      ),
      loading: _refreshing,
      onRefresh: _refresh,
      body: [
        RefAdaptiveGrid(
          minCellWidth: 150,
          children: [
            RefMetricCard(
              label: tr(context, 'chart_total'),
              value: '${rows.length}',
              icon: Icons.groups_rounded,
              tone: RefMetricTone.primary,
            ),
            RefMetricCard(
              label: tr(context, 'f_debtor'),
              value:
                  '${rows.where((row) => (_number(row, const ['debt', 'outstanding', 'balance_due', 'amount_due']) ?? 0) > 0).length}',
              icon: Icons.account_balance_wallet_outlined,
              tone: RefMetricTone.warning,
            ),
            RefMetricCard(
              label: tr(context, 'status_active'),
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
          hint: tx(
            context,
            uz: 'Ism, ID, guruh yoki maydon bo‘yicha qidirish',
            ru: 'Поиск по имени, ID, группе или полю',
            en: 'Search by name, ID, group or field',
          ),
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
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('live-students-enrolled-date-range'),
                onPressed: _pickEnrollmentRange,
                icon: const Icon(Icons.date_range_rounded),
                label: Text(
                  _enrollmentRange == null
                      ? tx(
                          context,
                          uz: 'Boshlagan sana: dan — gacha',
                          ru: 'Начало обучения: от — до',
                          en: 'Start date: from — to',
                        )
                      : '${_liveDateLabel(_enrollmentRange!.start)} — '
                            '${_liveDateLabel(_enrollmentRange!.end)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (_enrollmentRange != null) ...[
              const SizedBox(width: 4),
              IconButton(
                key: const ValueKey('live-students-reset-enrolled-date-range'),
                tooltip: tx(
                  context,
                  uz: 'Davrni tiklash',
                  ru: 'Сбросить период',
                  en: 'Reset period',
                ),
                onPressed: () => setState(() {
                  _enrollmentRange = null;
                  _page = 1;
                }),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const ValueKey('live-students-open-filters'),
            onPressed: _openFilters,
            icon: Icon(
              _filter == 0 ? Icons.tune_rounded : Icons.filter_alt_rounded,
            ),
            label: Text(
              _filter == 0
                  ? tx(context, uz: 'Filtrlar', ru: 'Фильтры', en: 'Filters')
                  : tx(
                      context,
                      uz: 'Filtrlar · 1',
                      ru: 'Фильтры · 1',
                      en: 'Filters · 1',
                    ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        RefSectionHeader(
          title: tr(context, 'students_title'),
          subtitle: tx(
            context,
            uz: '${filtered.length} ta natija · yangilash uchun torting',
            ru: '${filtered.length} результатов · потяните для обновления',
            en: '${filtered.length} results · pull to refresh',
          ),
        ),
        const SizedBox(height: 8),
        if (_error != null) _LiveError(message: _error!, onRetry: _refresh),
        if (_error == null && rows.isEmpty && !_refreshing)
          _LiveEmpty(
            icon: Icons.groups_outlined,
            message: tx(
              context,
              uz: 'API o‘quvchi qaytarmadi yoki rolda ruxsat yo‘q.',
              ru: 'API не вернул учеников или у роли нет доступа.',
              en: 'The API returned no students or this role has no access.',
            ),
          ),
        if (_error == null &&
            rows.isNotEmpty &&
            filtered.isEmpty &&
            !_refreshing)
          _LiveEmpty(
            icon: Icons.search_off_rounded,
            message: tx(
              context,
              uz: 'Qidiruv va filtr bo‘yicha natija topilmadi.',
              ru: 'Поиск и фильтры не дали результатов.',
              en: 'No results match the search and filters.',
            ),
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
            title: tx(
              context,
              uz: 'O‘quvchi profili',
              ru: 'Профиль ученика',
              en: 'Student profile',
            ),
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
                  name: _title(record, fallback: tr(context, 'unit_student')),
                  size: 46,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _title(record, fallback: tr(context, 'unit_student')),
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
                  label: tr(context, 'stat_attendance').toUpperCase(),
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
                  label: tr(context, 'stat_debt').toUpperCase(),
                  value: debt == null ? '—' : fmtMoneyShort(debt),
                  color: debt == null || debt == 0 ? c.success : c.danger,
                ),
                _MiniField(
                  label: tx(context, uz: 'MAYDONLAR', ru: 'ПОЛЯ', en: 'FIELDS'),
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
  bool _withGroupsOnly = false;
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
    final rows = teachers.where((row) {
      if (_withGroupsOnly && session.groupsForTeacher(row).isEmpty) {
        return false;
      }
      return _query.isEmpty || _searchable(row).contains(_query.toLowerCase());
    }).toList();
    final page = _pageWindow(rows, _page);
    return _LiveShell(
      title: tx(
        context,
        uz: 'O‘qituvchilar',
        ru: 'Преподаватели',
        en: 'Teachers',
      ),
      eyebrow: tx(
        context,
        uz: 'O‘QITUVCHILAR JAMOASI · ${session.totalFor('teachers')}',
        ru: 'КОМАНДА ПРЕПОДАВАТЕЛЕЙ · ${session.totalFor('teachers')}',
        en: 'TEACHING TEAM · ${session.totalFor('teachers')}',
      ),
      subtitle: tx(
        context,
        uz: 'O‘qituvchi profili, biriktirilgan guruhlar va o‘quvchilar',
        ru: 'Профили преподавателей, их группы и ученики',
        en: 'Teacher profiles, assigned groups and students',
      ),
      loading: _refreshing,
      onRefresh: _refresh,
      body: [
        Row(
          children: [
            Expanded(
              child: RefMetricCard(
                key: const ValueKey('live-teachers-all-metric'),
                label: 'O‘qituvchilar',
                value: '${teachers.length}',
                icon: Icons.school_rounded,
                tone: RefMetricTone.primary,
                onTap: () => setState(() => _withGroupsOnly = false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RefMetricCard(
                key: const ValueKey('live-teachers-groups-metric'),
                label: 'Guruhlar',
                value: '${groups.length}',
                icon: Icons.workspaces_rounded,
                tone: RefMetricTone.accent,
                onTap: () => setState(() => _withGroupsOnly = true),
              ),
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
      title: tx(context, uz: 'Xodimlar', ru: 'Сотрудники', en: 'Staff'),
      eyebrow: tx(
        context,
        uz: 'JAMOA · ${session.totalFor('staff')}',
        ru: 'КОМАНДА · ${session.totalFor('staff')}',
        en: 'TEAM · ${session.totalFor('staff')}',
      ),
      subtitle: tx(
        context,
        uz: 'Xodimlar, bo‘limlar va ish holati',
        ru: 'Сотрудники, департаменты и рабочий статус',
        en: 'Staff, departments and work status',
      ),
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
  bool _marking = false;
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
      await Future.wait([ApiScope.of(context).refresh('attendanceRecords')]);
      if (mounted) setState(() => _page = 1);
    } on ApiException catch (error) {
      _error = _liveApiError(error);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _markAttendance() async {
    if (_marking) return;
    final payload = await _jsonObjectEditor(
      context,
      title: 'Отметить посещаемость',
      initial: const {'lesson_id': '', 'records': <Map<String, dynamic>>[]},
    );
    if (payload == null || !mounted) return;
    final lessonId = apiText(payload.remove('lesson_id'));
    if (lessonId.isEmpty) {
      setState(
        () => _error = 'lesson_id обязателен для команды отметки посещаемости.',
      );
      return;
    }
    setState(() {
      _marking = true;
      _error = null;
    });
    try {
      await ApiScope.of(context).action(
        'POST',
        '/api/v1/attendance/lessons/${Uri.encodeComponent(lessonId)}/mark/',
        body: payload,
        refreshResources: const ['attendanceRecords'],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Посещаемость сохранена на сервере')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = _liveApiError(error));
    } finally {
      if (mounted) setState(() => _marking = false);
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
      title: 'Посещаемость tahlili',
      eyebrow: tx(
        context,
        uz: 'DAVOMAT · ${session.totalFor('attendanceRecords')}',
        ru: 'ПОСЕЩАЕМОСТЬ · ${session.totalFor('attendanceRecords')}',
        en: 'ATTENDANCE · ${session.totalFor('attendanceRecords')}',
      ),
      subtitle: tx(
        context,
        uz: 'Davomat xulosasi, qaydlar va tendensiyalar',
        ru: 'Сводка посещаемости, записи и динамика',
        en: 'Attendance summary, records and trends',
      ),
      loading: _refreshing,
      onRefresh: _refresh,
      body: [
        if (AppScope.of(context).role == SfRole.manager) ...[
          RefButton(
            key: const ValueKey('live-attendance-mark'),
            label: _marking ? 'Сохранение…' : 'Отметить посещаемость',
            leading: Icons.fact_check_rounded,
            block: true,
            onPressed: _marking ? null : _markAttendance,
          ),
          const SizedBox(height: 12),
        ],
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
          title: 'Посещаемость yozuvlari',
          subtitle: 'Pastga tortib yangilang',
        ),
        const SizedBox(height: 8),
        if (_error == null && records.isEmpty && !_refreshing)
          const _LiveEmpty(
            icon: Icons.how_to_reg_outlined,
            message: 'API не вернул записи или сводку посещаемости.',
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
        empty: 'Посещаемость yozuvi',
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
            title: 'Посещаемость yozuvi',
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
          sum +
          (_number(row, const [
                'amount_uzs',
                'amount',
                'paid_amount',
                'total',
              ]) ??
              0),
    );
    final invoices = session.records('invoices');
    final outstandingInvoices = invoices
        .where((row) {
          final status = _text(
            _value(row, const ['status', 'invoice_status', 'state']),
            empty: '',
          ).toLowerCase();
          return const {'issued', 'partially_paid', 'overdue'}.contains(status);
        })
        .toList(growable: false);
    final outstanding = <String, dynamic>{
      'total_uzs': outstandingInvoices.fold<num>(
        0,
        (sum, row) =>
            sum +
            (_number(row, const [
                  'total_uzs',
                  'amount_uzs',
                  'amount',
                  'total',
                ]) ??
                0),
      ),
      'invoice_count': outstandingInvoices.length,
      'overdue_count': outstandingInvoices
          .where(
            (row) =>
                _text(_value(row, const ['status']), empty: '').toLowerCase() ==
                'overdue',
          )
          .length,
    };
    return _LiveShell(
      title: 'Daromad va moliya',
      eyebrow: tx(
        context,
        uz: 'MOLIYA · ${session.totalFor('payments')} TO‘LOV',
        ru: 'ФИНАНСЫ · ${session.totalFor('payments')} ПЛАТЕЖЕЙ',
        en: 'FINANCE · ${session.totalFor('payments')} PAYMENTS',
      ),
      subtitle: tx(
        context,
        uz: 'To‘lovlar, hisoblar, xarajatlar va qarzdorlik',
        ru: 'Платежи, счета, расходы и задолженность',
        en: 'Payments, invoices, expenses and debt',
      ),
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
        _ObjectSection(title: 'Qarzdorlik · invoices API', value: outstanding),
        const SizedBox(height: 20),
        RefSectionHeader(
          title: 'So‘nggi to‘lovlar',
          subtitle: '${payments.length} ta to‘lov',
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
    final amount = _number(record, const [
      'amount_uzs',
      'amount',
      'paid_amount',
      'total',
    ]);
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

class LiveThreadsPage extends StatefulWidget {
  const LiveThreadsPage({super.key, required this.title});

  final String title;

  @override
  State<LiveThreadsPage> createState() => _LiveThreadsPageState();
}

class _LiveThreadsPageState extends State<LiveThreadsPage> {
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
      await ApiScope.of(context).refresh('threads');
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = _liveApiError(error));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ApiScope.of(context);
    final threads = session.records('threads');
    return _LiveShell(
      title: widget.title,
      eyebrow: tx(
        context,
        uz: 'SUHBATLAR · ${session.totalFor('threads')}',
        ru: 'ДИАЛОГИ · ${session.totalFor('threads')}',
        en: 'CONVERSATIONS · ${session.totalFor('threads')}',
      ),
      subtitle: tx(
        context,
        uz: 'Suhbatlarni o‘qing va xabar yuboring',
        ru: 'Читайте диалоги и отправляйте сообщения',
        en: 'Read conversations and send messages',
      ),
      loading: _refreshing,
      onRefresh: _refresh,
      body: [
        if (_error != null) _LiveError(message: _error!, onRetry: _refresh),
        if (_error == null && threads.isEmpty && !_refreshing)
          const _LiveEmpty(
            icon: Icons.forum_outlined,
            message: 'API suhbat qaytarmadi yoki ushbu rol uchun ruxsat yo‘q.',
          ),
        for (final thread in threads) ...[
          RefStatusTile(
            icon: Icons.chat_bubble_outline_rounded,
            title: _title(thread, fallback: 'Suhbat'),
            subtitle: _text(
              _value(thread, const [
                'last_message',
                'preview',
                'subject',
                'updated_at',
              ]),
              empty: 'Xabarlarni ochish',
            ),
            tone: RefMetricTone.primary,
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              sfPageRoute(
                _LiveThreadDetailPage(
                  thread: thread,
                  colors: SfTheme.of(context),
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
        ],
      ],
    );
  }
}

class _LiveThreadDetailPage extends StatefulWidget {
  const _LiveThreadDetailPage({required this.thread, required this.colors});

  final Map<String, dynamic> thread;
  final SfColors colors;

  @override
  State<_LiveThreadDetailPage> createState() => _LiveThreadDetailPageState();
}

class _LiveThreadDetailPageState extends State<_LiveThreadDetailPage> {
  final _composer = TextEditingController();
  List<Map<String, dynamic>> _messages = const [];
  bool _loading = false;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final id = _id(widget.thread);
    if (id.isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final session = ApiScope.of(context);
    try {
      final page = await session.threadMessages(id);
      await session.action(
        'POST',
        '/api/v1/messaging/threads/${Uri.encodeComponent(id)}/read/',
      );
      if (mounted) setState(() => _messages = page.items);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = _liveApiError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    final id = _id(widget.thread);
    if (text.isEmpty || id.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ApiScope.of(context).sendThreadMessage(id, text);
      _composer.clear();
      await _refresh();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = _liveApiError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: Column(
            children: [
              RefLargeHeader(
                title: _title(widget.thread, fallback: 'Suhbat'),
                eyebrow: 'LIVE MESSAGING',
                subtitle: '${_messages.length} ta xabar',
                leading: RefIconAction(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Ortga',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: _LiveError(message: _error!, onRetry: _refresh),
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[_messages.length - 1 - index];
                      final mine = _truthy(
                        _value(message, const ['is_mine', 'mine', 'from_me']),
                      );
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 560),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
                          decoration: BoxDecoration(
                            color: mine ? c.primary : c.surface,
                            borderRadius: BorderRadius.circular(15),
                            border: mine ? null : Border.all(color: c.border),
                          ),
                          child: Text(
                            _text(
                              _value(message, const [
                                'text',
                                'message',
                                'content',
                                'body',
                              ]),
                              empty: _text(
                                _value(message, const [
                                  'attachment_name',
                                  'file_name',
                                  'filename',
                                  'media_type',
                                  'message_type',
                                  'type',
                                ]),
                                empty: 'Вложение или системное сообщение',
                              ),
                            ),
                            style: RefType.ui(
                              size: 13,
                              color: mine ? Colors.white : c.ink,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 10, 10),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border(top: BorderSide(color: c.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _composer,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.newline,
                          decoration: const InputDecoration(
                            hintText: 'Xabar yozing…',
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      RefIconAction(
                        icon: Icons.send_rounded,
                        tooltip: 'Yuborish',
                        onPressed: _sending ? null : _send,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

class LiveResourceSection {
  const LiveResourceSection({
    required this.resource,
    required this.title,
    required this.icon,
  });

  final String resource;
  final String title;
  final IconData icon;
}

/// A compact live workspace for menu items backed by several related OpenAPI
/// collections (schedule, permissions, placement and audit case management).
class LiveMultiCollectionPage extends StatefulWidget {
  const LiveMultiCollectionPage({
    super.key,
    required this.title,
    required this.sections,
  });

  final String title;
  final List<LiveResourceSection> sections;

  @override
  State<LiveMultiCollectionPage> createState() =>
      _LiveMultiCollectionPageState();
}

class _LiveMultiCollectionPageState extends State<LiveMultiCollectionPage> {
  final _search = TextEditingController();
  bool _refreshing = false;
  String? _creatingResource;
  String _query = '';
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
    final session = ApiScope.of(context);
    try {
      await Future.wait(
        widget.sections.map((section) async {
          try {
            await session.refresh(section.resource);
          } on ApiException catch (error) {
            if (error.status != HttpStatus.forbidden &&
                error.status != HttpStatus.notFound) {
              rethrow;
            }
          }
        }),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = _liveApiError(error));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _create(LiveResourceSection section) async {
    if (_creatingResource != null) return;
    final payload = section.resource == 'branches'
        ? await _branchEditor(context, title: 'Добавить филиал')
        : await _jsonObjectEditor(
            context,
            title: 'Добавить · ${section.title}',
          );
    if (payload == null || !mounted) return;
    setState(() {
      _creatingResource = section.resource;
      _error = null;
    });
    try {
      await ApiScope.of(context).create(section.resource, payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${section.title}: запись создана')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = _liveApiError(error));
    } finally {
      if (mounted) setState(() => _creatingResource = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ApiScope.of(context);
    final total = widget.sections.fold<int>(
      0,
      (sum, section) => sum + session.totalFor(section.resource),
    );
    return _LiveShell(
      title: widget.title,
      eyebrow: tx(
        context,
        uz: 'BOG‘LIQ JARAYONLAR · $total',
        ru: 'СВЯЗАННЫЕ ПРОЦЕССЫ · $total',
        en: 'CONNECTED WORKFLOWS · $total',
      ),
      subtitle: tx(
        context,
        uz: 'Barcha bog‘liq bo‘limlar bitta ish maydonida',
        ru: 'Связанные разделы и действия в одном рабочем пространстве',
        en: 'Related sections and actions in one workspace',
      ),
      loading: _refreshing,
      onRefresh: _refresh,
      body: [
        RefSearchField(
          controller: _search,
          hint: tx(
            context,
            uz: 'Barcha bo‘limlarda qidirish',
            ru: 'Поиск по всем разделам',
            en: 'Search all sections',
          ),
          onChanged: (value) => setState(() => _query = value.toLowerCase()),
        ),
        const SizedBox(height: 16),
        if (_error != null) _LiveError(message: _error!, onRetry: _refresh),
        for (final section in widget.sections) ...[
          Builder(
            builder: (context) {
              final error = session.resourceError(section.resource);
              final records = session
                  .records(section.resource)
                  .where(
                    (record) =>
                        _query.isEmpty || _searchable(record).contains(_query),
                  )
                  .toList(growable: false);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RefSectionHeader(
                    title: section.title,
                    subtitle:
                        '${records.length} ${tx(context, uz: 'ta yozuv', ru: 'записей', en: 'records')}',
                  ),
                  const SizedBox(height: 8),
                  if (_canMutateResource(context, section.resource) &&
                      kApiCreatableResources.contains(section.resource)) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: RefButton(
                        label: _creatingResource == section.resource
                            ? 'Сохранение…'
                            : 'Добавить',
                        kind: RefButtonKind.soft,
                        leading: Icons.add_rounded,
                        onPressed: _creatingResource == null
                            ? () => _create(section)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (error != null)
                    _LiveError(
                      message: _liveApiError(error),
                      onRetry: () => session.refresh(section.resource),
                    )
                  else if (records.isEmpty && !_refreshing)
                    _LiveEmpty(
                      icon: section.icon,
                      message: _query.isEmpty
                          ? tx(
                              context,
                              uz: 'Bu bo‘limda hozircha ma’lumot yo‘q.',
                              ru: 'В этом разделе пока нет данных.',
                              en: 'There is no data in this section yet.',
                            )
                          : tx(
                              context,
                              uz: 'Qidiruv bo‘yicha yozuv topilmadi.',
                              ru: 'По вашему запросу ничего не найдено.',
                              en: 'Nothing matched your search.',
                            ),
                    )
                  else
                    for (final record in records) ...[
                      _GenericRecordCard(
                        record: record,
                        title: section.title,
                        resource: section.resource,
                        icon: section.icon,
                      ),
                      const SizedBox(height: 8),
                    ],
                ],
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _LiveCollectionPageState extends State<LiveCollectionPage> {
  final _search = TextEditingController();
  String _query = '';
  int _metricFilter = 0;
  DateTimeRange? _range;
  bool _refreshing = false;
  bool _mutating = false;
  bool _exporting = false;
  Object? _exportResult;
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
    } on ApiException catch (error) {
      _error = _liveApiError(error);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _create() async {
    if (_mutating) return;
    final payload = widget.resource == 'branches'
        ? await _branchEditor(context, title: 'Добавить филиал')
        : await _jsonObjectEditor(context, title: 'Добавить · ${widget.title}');
    if (payload == null || !mounted) return;
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      await ApiScope.of(context).create(widget.resource, payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Запись создана сервером')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = _liveApiError(error));
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final value = await showRefDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _range,
      title: 'Период',
    );
    if (value != null && mounted) setState(() => _range = value);
  }

  Future<void> _openGroupStudents(
    ApiSession session,
    List<Map<String, dynamic>> groups,
  ) async {
    final byId = <String, Map<String, dynamic>>{};
    for (final group in groups) {
      for (final student in session.groupSnapshot(group).students) {
        byId[_id(student)] = student;
      }
    }
    final students = byId.values.toList(growable: false);
    final c = SfTheme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SfTheme(
        colors: c,
        child: DraggableScrollableSheet(
          initialChildSize: .72,
          minChildSize: .42,
          maxChildSize: .94,
          expand: false,
          builder: (_, controller) => Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(26),
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
                  child: RefSectionHeader(
                    title: 'Ученики выбранных групп',
                    subtitle: '${students.length} записей API',
                    trailing: IconButton(
                      tooltip: 'Закрыть',
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ),
                Expanded(
                  child: students.isEmpty
                      ? const _LiveEmpty(
                          icon: Icons.groups_outlined,
                          message: 'API не вернул учеников этих групп.',
                        )
                      : ListView.separated(
                          controller: controller,
                          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                          itemCount: students.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, index) => _GenericRecordCard(
                            record: students[index],
                            title: 'Ученик',
                            resource: 'students',
                            icon: Icons.person_outline_rounded,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportAudit() async {
    if (_exporting) return;
    setState(() {
      _exporting = true;
      _error = null;
    });
    try {
      final result = await ApiScope.of(
        context,
      ).readPath('/api/v1/audit/export/');
      if (mounted) setState(() => _exportResult = result ?? const {});
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = _liveApiError(error));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ApiScope.of(context);
    final all = session.records(widget.resource);
    final searched = all.where((row) {
      if (_query.isNotEmpty &&
          !_searchable(row).contains(_query.toLowerCase())) {
        return false;
      }
      if (widget.resource == 'groups' && _range != null) {
        return apiRecordWithinInclusivePeriod(
          row,
          from: _range!.start,
          to: _range!.end,
        );
      }
      return true;
    }).toList();
    final rows = searched.where((row) {
      if (widget.resource == 'groups') {
        final status = _text(
          _value(row, const ['status', 'state']),
        ).toLowerCase();
        final debt =
            _number(row, const [
              'debtor_count',
              'debtors_count',
              'debt_count',
              'outstanding_count',
            ]) ??
            0;
        if (_metricFilter == 1) {
          return status.isEmpty ||
              status.contains('active') ||
              status.contains('faol');
        }
        if (_metricFilter == 2) return debt > 0;
      }
      if (widget.resource == 'parents') {
        final debt =
            _number(row, const ['debt', 'debt_amount', 'outstanding_amount']) ??
            0;
        if (_metricFilter == 3) {
          final lastCall = apiRecordDate({
            'date': _value(row, const [
              'last_call_at',
              'last_call',
              'contacted_at',
            ]),
          });
          return lastCall == null ||
              DateTime.now().difference(lastCall).inDays > 7;
        }
        if (_metricFilter == 4) return debt > 0;
      }
      if (widget.resource == 'branches' && _metricFilter == 10) {
        return _isActiveRecord(row);
      }
      if (widget.resource == 'departments') {
        if (_metricFilter == 20) return _isActiveRecord(row);
        if (_metricFilter == 21) {
          return _value(row, const [
                'manager',
                'manager_name',
                'head',
                'head_name',
                'responsible',
              ]) !=
              null;
        }
      }
      if (widget.resource == 'studentRisk') {
        final risk = _text(
          _value(row, const ['risk_level', 'level', 'severity', 'status']),
          empty: '',
        ).toLowerCase();
        if (_metricFilter == 30) {
          return risk.contains('high') ||
              risk.contains('critical') ||
              risk.contains('yuqori') ||
              risk.contains('высок');
        }
        if (_metricFilter == 31) {
          return risk.contains('medium') ||
              risk.contains('o‘rta') ||
              risk.contains('сред');
        }
      }
      return true;
    }).toList();
    final storedError = session.resourceError(widget.resource);
    final displayedError =
        _error ?? (storedError == null ? null : _liveApiError(storedError));
    return _LiveShell(
      title: widget.title,
      eyebrow: _collectionEyebrow(
        context,
        widget.resource,
        session.totalFor(widget.resource),
      ),
      subtitle: _collectionSubtitle(context, widget.resource),
      loading: _refreshing,
      onRefresh: _refresh,
      body: [
        if (widget.resource == 'branches') ...[
          RefAdaptiveGrid(
            children: [
              RefMetricCard(
                label: tx(
                  context,
                  uz: 'Barcha filiallar',
                  ru: 'Все филиалы',
                  en: 'All branches',
                ),
                value: '${searched.length}',
                icon: Icons.apartment_rounded,
                tone: RefMetricTone.primary,
                compact: true,
                uppercaseLabel: false,
                onTap: () => setState(() => _metricFilter = 0),
              ),
              RefMetricCard(
                label: tx(context, uz: 'Faol', ru: 'Активные', en: 'Active'),
                value: '${searched.where(_isActiveRecord).length}',
                icon: Icons.check_circle_outline_rounded,
                tone: RefMetricTone.success,
                compact: true,
                uppercaseLabel: false,
                onTap: () => setState(() => _metricFilter = 10),
              ),
              RefMetricCard(
                label: tx(
                  context,
                  uz: 'O‘quvchi sig‘imi',
                  ru: 'Мест для учеников',
                  en: 'Student capacity',
                ),
                value:
                    '${searched.fold<num>(0, (sum, row) => sum + (_number(row, const ['max_students', 'student_capacity', 'capacity']) ?? 0)).round()}',
                icon: Icons.groups_rounded,
                tone: RefMetricTone.accent,
                compact: true,
                uppercaseLabel: false,
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        if (widget.resource == 'groups') ...[
          Row(
            children: [
              Expanded(
                child: RefMetricCard(
                  key: const ValueKey('live-groups-active-metric'),
                  label: 'Активные группы',
                  value:
                      '${searched.where((row) {
                        final status = _text(_value(row, const ['status', 'state'])).toLowerCase();
                        return status.isEmpty || status.contains('active') || status.contains('faol');
                      }).length}',
                  icon: Icons.workspaces_rounded,
                  tone: RefMetricTone.primary,
                  compact: true,
                  uppercaseLabel: false,
                  onTap: () => setState(() => _metricFilter = 1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RefMetricCard(
                  key: const ValueKey('live-groups-students-metric'),
                  label: 'Ученики',
                  value:
                      '${searched.fold<num>(0, (sum, row) => sum + (_number(row, const ['student_count', 'students_count', 'members_count']) ?? 0)).round()}',
                  icon: Icons.groups_rounded,
                  tone: RefMetricTone.success,
                  compact: true,
                  uppercaseLabel: false,
                  onTap: () => _openGroupStudents(session, searched),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: RefMetricCard(
              key: const ValueKey('live-groups-debt-metric'),
              label: 'Группы с задолженностью',
              value:
                  '${searched.where((row) => (_number(row, const ['debtor_count', 'debtors_count', 'debt_count', 'outstanding_count']) ?? 0) > 0).length}',
              icon: Icons.flag_rounded,
              tone: RefMetricTone.warning,
              compact: true,
              uppercaseLabel: false,
              onTap: () => setState(() => _metricFilter = 2),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: RefButton(
                  label: _range == null
                      ? 'От — до'
                      : '${_shortDate(_range!.start)} — ${_shortDate(_range!.end)}',
                  leading: Icons.date_range_rounded,
                  kind: RefButtonKind.ghost,
                  onPressed: _pickRange,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                key: const ValueKey('live-groups-reset'),
                tooltip: 'Сбросить фильтры',
                onPressed: _metricFilter == 0 && _range == null
                    ? null
                    : () => setState(() {
                        _metricFilter = 0;
                        _range = null;
                      }),
                icon: const Icon(Icons.restart_alt_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        if (widget.resource == 'parents') ...[
          Row(
            children: [
              Expanded(
                child: RefMetricCard(
                  key: const ValueKey('live-parents-all-metric'),
                  label: 'Родители',
                  value: '${searched.length}',
                  icon: Icons.family_restroom_rounded,
                  tone: RefMetricTone.primary,
                  compact: true,
                  onTap: () => setState(() => _metricFilter = 0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RefMetricCard(
                  key: const ValueKey('live-parents-callback-metric'),
                  label: 'Нужен звонок',
                  value:
                      '${searched.where((row) {
                        final date = apiRecordDate({
                          'date': _value(row, const ['last_call_at', 'last_call', 'contacted_at']),
                        });
                        return date == null || DateTime.now().difference(date).inDays > 7;
                      }).length}',
                  icon: Icons.phone_callback_outlined,
                  tone: RefMetricTone.warning,
                  compact: true,
                  onTap: () => setState(() => _metricFilter = 3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: RefMetricCard(
              key: const ValueKey('live-parents-debt-metric'),
              label: 'Есть задолженность',
              value:
                  '${searched.where((row) => (_number(row, const ['debt', 'debt_amount', 'outstanding_amount']) ?? 0) > 0).length}',
              icon: Icons.account_balance_wallet_outlined,
              tone: RefMetricTone.danger,
              compact: true,
              onTap: () => setState(() => _metricFilter = 4),
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (widget.resource == 'departments') ...[
          RefAdaptiveGrid(
            children: [
              RefMetricCard(
                label: tx(
                  context,
                  uz: 'Barcha bo‘limlar',
                  ru: 'Все департаменты',
                  en: 'All departments',
                ),
                value: '${searched.length}',
                icon: Icons.account_tree_outlined,
                tone: RefMetricTone.primary,
                compact: true,
                uppercaseLabel: false,
                onTap: () => setState(() => _metricFilter = 0),
              ),
              RefMetricCard(
                label: tx(context, uz: 'Faol', ru: 'Активные', en: 'Active'),
                value: '${searched.where(_isActiveRecord).length}',
                icon: Icons.verified_outlined,
                tone: RefMetricTone.success,
                compact: true,
                uppercaseLabel: false,
                onTap: () => setState(() => _metricFilter = 20),
              ),
              RefMetricCard(
                label: tx(
                  context,
                  uz: 'Rahbar biriktirilgan',
                  ru: 'Есть руководитель',
                  en: 'Leader assigned',
                ),
                value:
                    '${searched.where((row) => _value(row, const ['manager', 'manager_name', 'head', 'head_name', 'responsible']) != null).length}',
                icon: Icons.badge_outlined,
                tone: RefMetricTone.accent,
                compact: true,
                uppercaseLabel: false,
                onTap: () => setState(() => _metricFilter = 21),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        if (widget.resource == 'studentRisk') ...[
          RefAdaptiveGrid(
            children: [
              RefMetricCard(
                label: tx(
                  context,
                  uz: 'Barcha signallar',
                  ru: 'Все сигналы',
                  en: 'All signals',
                ),
                value: '${searched.length}',
                icon: Icons.monitor_heart_outlined,
                tone: RefMetricTone.primary,
                compact: true,
                uppercaseLabel: false,
                onTap: () => setState(() => _metricFilter = 0),
              ),
              RefMetricCard(
                label: tx(
                  context,
                  uz: 'Yuqori xavf',
                  ru: 'Высокий риск',
                  en: 'High risk',
                ),
                value:
                    '${searched.where((row) {
                      final value = _text(_value(row, const ['risk_level', 'level', 'severity', 'status']), empty: '').toLowerCase();
                      return value.contains('high') || value.contains('critical') || value.contains('yuqori') || value.contains('высок');
                    }).length}',
                icon: Icons.priority_high_rounded,
                tone: RefMetricTone.danger,
                compact: true,
                uppercaseLabel: false,
                onTap: () => setState(() => _metricFilter = 30),
              ),
              RefMetricCard(
                label: tx(
                  context,
                  uz: 'O‘rta xavf',
                  ru: 'Средний риск',
                  en: 'Medium risk',
                ),
                value:
                    '${searched.where((row) {
                      final value = _text(_value(row, const ['risk_level', 'level', 'severity', 'status']), empty: '').toLowerCase();
                      return value.contains('medium') || value.contains('o‘rta') || value.contains('сред');
                    }).length}',
                icon: Icons.warning_amber_rounded,
                tone: RefMetricTone.warning,
                compact: true,
                uppercaseLabel: false,
                onTap: () => setState(() => _metricFilter = 31),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        if (widget.resource == 'audit') ...[
          RefButton(
            label: _exporting
                ? 'Экспорт готовится…'
                : 'Экспортировать audit log',
            leading: Icons.file_download_outlined,
            block: true,
            onPressed: _exporting ? null : _exportAudit,
          ),
          if (_exportResult != null) ...[
            const SizedBox(height: 10),
            _ObjectSection(
              title: 'Результат экспорта API',
              value: _exportResult!,
            ),
          ],
          const SizedBox(height: 12),
        ],
        if (_canMutateResource(context, widget.resource) &&
            kApiCreatableResources.contains(widget.resource)) ...[
          RefButton(
            label: _mutating ? 'Сохранение…' : 'Добавить',
            leading: Icons.add_rounded,
            block: true,
            onPressed: _mutating ? null : _create,
          ),
          const SizedBox(height: 12),
        ],
        RefSearchField(
          controller: _search,
          hint: tx(
            context,
            uz: 'Nomi, holati yoki boshqa ma’lumot bo‘yicha qidirish',
            ru: 'Поиск по имени, статусу или другим данным',
            en: 'Search by name, status or other data',
          ),
          onChanged: (value) => setState(() {
            _query = value;
          }),
        ),
        const SizedBox(height: 20),
        RefSectionHeader(
          title: widget.title,
          subtitle:
              '${rows.length} ${tx(context, uz: 'ta natija', ru: 'результатов', en: 'results')}',
        ),
        const SizedBox(height: 8),
        if (displayedError != null)
          _LiveError(message: displayedError, onRetry: _refresh),
        if (displayedError == null && all.isEmpty && !_refreshing)
          _LiveEmpty(
            icon: widget.icon,
            message: tx(
              context,
              uz: 'Bu bo‘limda hozircha ma’lumot yo‘q.',
              ru: 'В этом разделе пока нет данных.',
              en: 'There is no data in this section yet.',
            ),
          ),
        if (displayedError == null &&
            all.isNotEmpty &&
            rows.isEmpty &&
            !_refreshing)
          _LiveEmpty(
            icon: Icons.search_off_rounded,
            message: tx(
              context,
              uz: 'Qidiruv bo‘yicha ma’lumot topilmadi.',
              ru: 'По вашему запросу ничего не найдено.',
              en: 'Nothing matched your search.',
            ),
          ),
        for (var index = 0; index < rows.length; index++) ...[
          RefStaggeredReveal(
            order: index,
            child: _GenericRecordCard(
              record: rows[index],
              title: widget.title,
              resource: widget.resource,
              icon: widget.icon,
            ),
          ),
          const SizedBox(height: 9),
        ],
      ],
    );
  }
}

String _recordTitleForResource(
  Map<String, dynamic> record,
  String resource,
  String fallback,
) => switch (resource) {
  'audit' => _text(
    _value(record, const ['action', 'event', 'event_type', 'operation']),
    empty: _title(record, fallback: fallback),
  ),
  'studentRisk' => _text(
    _value(record, const ['student_name', 'student', 'full_name', 'name']),
    empty: _title(record, fallback: fallback),
  ),
  _ => _title(record, fallback: fallback),
};

String _recordStatus(Map<String, dynamic> record, String resource) {
  if (resource == 'branches' || resource == 'departments') {
    final active = _value(record, const ['is_active', 'active']);
    if (active != null) return _truthy(active) ? 'active' : 'inactive';
  }
  return _text(
    _value(record, const [
      'risk_level',
      'severity',
      'status',
      'state',
      'result',
    ]),
    empty: '',
  );
}

RefMetricTone _recordTone(String status) {
  final value = status.toLowerCase();
  if (value.contains('critical') ||
      value.contains('high') ||
      value.contains('failed') ||
      value.contains('inactive') ||
      value.contains('высок')) {
    return RefMetricTone.danger;
  }
  if (value.contains('medium') ||
      value.contains('pending') ||
      value.contains('warning') ||
      value.contains('сред')) {
    return RefMetricTone.warning;
  }
  if (value.contains('active') ||
      value.contains('success') ||
      value.contains('paid') ||
      value.contains('faol') ||
      value.contains('актив')) {
    return RefMetricTone.success;
  }
  return RefMetricTone.primary;
}

RefPillTone _recordPillTone(String status) => switch (_recordTone(status)) {
  RefMetricTone.danger => RefPillTone.danger,
  RefMetricTone.warning => RefPillTone.warning,
  RefMetricTone.success => RefPillTone.success,
  RefMetricTone.accent => RefPillTone.accent,
  RefMetricTone.primary => RefPillTone.primary,
  RefMetricTone.neutral => RefPillTone.neutral,
};

String _localizedRecordStatus(BuildContext context, String status) {
  final value = status.toLowerCase();
  if (value == 'active' || value == 'faol') {
    return tx(context, uz: 'Faol', ru: 'Активен', en: 'Active');
  }
  if (value == 'inactive') {
    return tx(context, uz: 'Nofaol', ru: 'Неактивен', en: 'Inactive');
  }
  if (value == 'high' || value == 'critical') {
    return tx(context, uz: 'Yuqori xavf', ru: 'Высокий риск', en: 'High risk');
  }
  if (value == 'medium') {
    return tx(context, uz: 'O‘rta xavf', ru: 'Средний риск', en: 'Medium risk');
  }
  if (value == 'low') {
    return tx(context, uz: 'Past xavf', ru: 'Низкий риск', en: 'Low risk');
  }
  return status;
}

List<({IconData icon, String value})> _recordFacts(
  Map<String, dynamic> record,
  String resource,
) {
  String read(List<String> keys) => _text(_value(record, keys), empty: '');
  final values = switch (resource) {
    'branches' => [
      (
        icon: Icons.location_on_outlined,
        value: read(const ['address', 'location', 'city']),
      ),
      (
        icon: Icons.phone_outlined,
        value: read(const ['phone', 'phone_number']),
      ),
      (
        icon: Icons.groups_outlined,
        value: read(const ['max_students', 'student_capacity', 'capacity']),
      ),
      (
        icon: Icons.schedule_rounded,
        value: read(const ['working_hours', 'timezone']),
      ),
    ],
    'groups' => [
      (
        icon: Icons.school_outlined,
        value: read(const [
          'teacher_name',
          'teacher',
          'instructor_name',
          'instructor',
        ]),
      ),
      (
        icon: Icons.apartment_outlined,
        value: read(const ['branch_name', 'branch']),
      ),
      (
        icon: Icons.groups_outlined,
        value: read(const ['student_count', 'students_count', 'members_count']),
      ),
      (
        icon: Icons.schedule_rounded,
        value: read(const ['schedule', 'lesson_time', 'time']),
      ),
    ],
    'parents' => [
      (
        icon: Icons.child_care_outlined,
        value: read(const ['child_name', 'student_name', 'child', 'student']),
      ),
      (
        icon: Icons.school_outlined,
        value: read(const ['teacher_name', 'teacher']),
      ),
      (
        icon: Icons.calendar_today_outlined,
        value: read(const [
          'education_started',
          'start_date',
          'enrolled_at',
          'created_at',
        ]),
      ),
      (
        icon: Icons.phone_callback_outlined,
        value: read(const ['last_call_at', 'last_call', 'contacted_at']),
      ),
    ],
    'departments' => [
      (
        icon: Icons.apartment_outlined,
        value: read(const ['branch_name', 'branch']),
      ),
      (
        icon: Icons.badge_outlined,
        value: read(const ['manager_name', 'manager', 'head_name', 'head']),
      ),
      (
        icon: Icons.assignment_ind_outlined,
        value: read(const ['responsible_name', 'responsible', 'owner']),
      ),
      (
        icon: Icons.groups_outlined,
        value: read(const ['staff_count', 'employees_count', 'member_count']),
      ),
    ],
    'studentRisk' => [
      (
        icon: Icons.info_outline_rounded,
        value: read(const ['reason', 'risk_reason', 'description', 'signal']),
      ),
      (
        icon: Icons.insights_outlined,
        value: read(const ['score', 'risk_score', 'probability']),
      ),
      (icon: Icons.groups_outlined, value: read(const ['group_name', 'group'])),
      (
        icon: Icons.calendar_today_outlined,
        value: read(const ['detected_at', 'created_at', 'date']),
      ),
    ],
    'audit' => [
      (
        icon: Icons.person_outline_rounded,
        value: read(const ['actor_name', 'actor', 'user_name', 'username']),
      ),
      (
        icon: Icons.category_outlined,
        value: read(const ['entity_type', 'object_type', 'resource']),
      ),
      (
        icon: Icons.schedule_rounded,
        value: read(const ['created_at', 'timestamp', 'date']),
      ),
      (
        icon: Icons.tag_rounded,
        value: read(const ['request_id', 'entity_id', 'object_id']),
      ),
    ],
    _ => [
      (
        icon: Icons.apartment_outlined,
        value: read(const [
          'branch_name',
          'branch',
          'department_name',
          'department',
        ]),
      ),
      (
        icon: Icons.calendar_today_outlined,
        value: read(const ['created_at', 'date', 'updated_at']),
      ),
    ],
  };
  return values.where((item) => item.value.isNotEmpty).take(4).toList();
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
    final recordTitle = _recordTitleForResource(record, resource, title);
    final id = _id(record);
    final status = _recordStatus(record, resource);
    final tone = _recordTone(status);
    final color = switch (tone) {
      RefMetricTone.danger => c.danger,
      RefMetricTone.warning => c.warn,
      RefMetricTone.success => c.success,
      RefMetricTone.accent => c.accentInk,
      RefMetricTone.primary => c.primary,
      RefMetricTone.neutral => c.ink2,
    };
    final facts = _recordFacts(record, resource);
    void openDetails() => Navigator.of(context).push(
      sfPageRoute(
        LiveRecordDetailPage(
          resource: resource,
          initial: record,
          title: resource == 'payments'
              ? tx(
                  context,
                  uz: 'To‘lov tafsiloti',
                  ru: 'Детали платежа',
                  en: 'Payment details',
                )
              : title,
          colors: c,
        ),
      ),
    );
    return Semantics(
      key: ValueKey('live-$resource-${id.isEmpty ? recordTitle : id}'),
      button: true,
      label:
          '$recordTitle. ${tx(context, uz: 'Tafsilotlarni ochish', ru: 'Открыть подробности', en: 'Open details')}',
      child: RefPressable(
        onPressed: openDetails,
        borderRadius: RefRadius.card,
        semanticLabel: recordTitle,
        child: RefSurfaceCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (resource == 'parents')
                    SfAvatar(name: recordTitle, size: 44)
                  else
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .12),
                        borderRadius: RefRadius.md,
                      ),
                      child: SizedBox(
                        width: 42,
                        height: 42,
                        child: Icon(icon, size: 21, color: color),
                      ),
                    ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      recordTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: RefType.ui(
                        size: 14.5,
                        weight: FontWeight.w800,
                        color: c.ink,
                      ),
                    ),
                  ),
                  if (status.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    RefPill(
                      label: _localizedRecordStatus(context, status),
                      tone: _recordPillTone(status),
                    ),
                  ] else
                    Icon(Icons.chevron_right_rounded, color: c.muted),
                ],
              ),
              if (facts.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 7,
                  children: [
                    for (final fact in facts)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: c.surface2,
                          borderRadius: RefRadius.pill,
                          border: Border.all(color: c.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(fact.icon, size: 14, color: c.muted),
                              const SizedBox(width: 5),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 220,
                                ),
                                child: Text(
                                  fact.value,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: RefType.ui(size: 11.5, color: c.ink2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      resource == 'parents'
                          ? tx(
                              context,
                              uz: 'Batafsil',
                              ru: 'Подробнее',
                              en: 'Details',
                            )
                          : tx(
                              context,
                              uz: 'Ochish',
                              ru: 'Открыть',
                              en: 'Open',
                            ),
                      style: RefType.ui(
                        size: 12,
                        weight: FontWeight.w700,
                        color: c.primary,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: c.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveRecordDetailPageState extends State<LiveRecordDetailPage> {
  late Map<String, dynamic> _record = widget.initial;
  bool _loading = false;
  bool _acting = false;
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
      final session = ApiScope.of(context);
      final detail = await session.detail(widget.resource, id);
      if (detail != null && mounted) setState(() => _record = detail);
      final related = switch (widget.resource) {
        'groups' => const [
          'students',
          'attendanceRecords',
          'payments',
          'audit',
          'exams',
        ],
        'teachers' => const ['groups', 'students'],
        'parents' => const ['students', 'payments'],
        'departments' => const ['staff'],
        _ => const <String>[],
      };
      await Future.wait(
        related.map((resource) async {
          try {
            await session.refresh(resource);
          } on ApiException catch (error) {
            if (error.isUnauthorized ||
                error.status == HttpStatus.paymentRequired) {
              rethrow;
            }
            // The owning detail remains usable. The related section reads the
            // error retained by ApiSession and never substitutes demo data.
          }
        }),
      );
    } on ApiException catch (error) {
      _error = _liveApiError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickGroupRange() async {
    final now = DateTime.now();
    final selected = await showRefDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange:
          _groupRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month - 1, now.day),
            end: now,
          ),
      title: 'Период истории группы',
    );
    if (selected != null && mounted) setState(() => _groupRange = selected);
  }

  Future<Map<String, dynamic>?> _actionPayload(String label) async {
    final controller = TextEditingController(text: '{}');
    String? validation;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SfTheme(
        colors: widget.colors,
        child: StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                16,
                18,
                18 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    label,
                    style: RefType.ui(
                      size: 17,
                      weight: FontWeight.w800,
                      color: SfTheme.of(context).ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'OpenAPI требует JSON-объект, но не публикует состав полей. '
                    'Для команды без параметров оставьте {}.',
                    style: RefType.ui(
                      size: 12,
                      color: SfTheme.of(context).muted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    minLines: 3,
                    maxLines: 8,
                    keyboardType: TextInputType.multiline,
                    style: RefType.mono(
                      size: 12,
                      color: SfTheme.of(context).ink,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Данные команды · JSON',
                      errorText: validation,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: RefButton(
                          label: 'Отмена',
                          kind: RefButtonKind.ghost,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RefButton(
                          label: 'Выполнить',
                          onPressed: () {
                            try {
                              final decoded = jsonDecode(controller.text);
                              if (decoded is! Map) {
                                throw const FormatException();
                              }
                              Navigator.of(
                                context,
                              ).pop(Map<String, dynamic>.from(decoded));
                            } on FormatException {
                              setSheetState(
                                () => validation =
                                    'Введите корректный JSON-объект',
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
    return result;
  }

  Future<void> _runRecordAction(String operation, String label) async {
    if (_acting) return;
    final id = _id(_record);
    if (id.isEmpty) return;
    final payload = await _actionPayload(label);
    if (payload == null || !mounted) return;
    setState(() {
      _acting = true;
      _error = null;
    });
    try {
      await ApiScope.of(context).resourceAction(
        widget.resource,
        id,
        operation,
        body: payload,
        refreshResources: widget.resource == 'approvals'
            ? const ['approvalLedger']
            : const [],
      );
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$label: команда выполнена')));
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = _liveApiError(error));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _editTeacherPayoutPolicy() async {
    if (_acting) return;
    final id = _id(_record);
    if (id.isEmpty) return;
    setState(() {
      _acting = true;
      _error = null;
    });
    Map<String, dynamic>? current;
    try {
      current = await ApiScope.of(context).teacherPayoutPolicy(id);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = _liveApiError(error));
      return;
    } finally {
      if (mounted) setState(() => _acting = false);
    }
    if (!mounted) return;
    final payload = await _jsonObjectEditor(
      context,
      title: 'Политика выплат преподавателя',
      initial: current ?? const <String, dynamic>{},
    );
    if (payload == null || !mounted) return;
    setState(() {
      _acting = true;
      _error = null;
    });
    try {
      await ApiScope.of(context).saveTeacherPayoutPolicy(id, payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Политика выплат сохранена')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = _liveApiError(error));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _updateRecord() async {
    if (_acting) return;
    final id = _id(_record);
    if (id.isEmpty) return;
    final payload = widget.resource == 'branches'
        ? await _branchEditor(
            context,
            title: 'Изменить филиал',
            initial: _record,
          )
        : await _jsonObjectEditor(
            context,
            title: 'Изменить · ${widget.title}',
            initial: _record,
          );
    if (payload == null || !mounted) return;
    setState(() {
      _acting = true;
      _error = null;
    });
    try {
      final updated = await ApiScope.of(
        context,
      ).update(widget.resource, id, payload);
      if (updated != null && mounted) setState(() => _record = updated);
      await _refresh();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = _liveApiError(error));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _deleteRecord() async {
    if (_acting) return;
    final id = _id(_record);
    if (id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить запись?'),
        content: const Text(
          'Команда будет отправлена на сервер. Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _acting = true);
    try {
      await ApiScope.of(context).remove(widget.resource, id);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _acting = false;
          _error = _liveApiError(error);
        });
      }
    }
  }

  List<({String operation, String label, RefButtonKind kind})>
  _recordActions() => switch (widget.resource) {
    'students' => const [
      (
        operation: 'transition',
        label: 'Изменить этап',
        kind: RefButtonKind.soft,
      ),
      (operation: 'block', label: 'Заблокировать', kind: RefButtonKind.danger),
      (
        operation: 'unblock',
        label: 'Разблокировать',
        kind: RefButtonKind.primary,
      ),
    ],
    'groups' => const [
      (
        operation: 'enroll',
        label: 'Зачислить ученика',
        kind: RefButtonKind.primary,
      ),
      (
        operation: 'move-student',
        label: 'Перевести ученика',
        kind: RefButtonKind.soft,
      ),
      (
        operation: 'remove-student',
        label: 'Убрать ученика',
        kind: RefButtonKind.danger,
      ),
      (
        operation: 'unarchive',
        label: 'Вернуть из архива',
        kind: RefButtonKind.ghost,
      ),
    ],
    'approvals' => const [
      (operation: 'approve', label: 'Одобрить', kind: RefButtonKind.primary),
      (operation: 'reject', label: 'Отклонить', kind: RefButtonKind.danger),
      (operation: 'cancel', label: 'Отменить', kind: RefButtonKind.ghost),
      (operation: 'disburse', label: 'Выплатить', kind: RefButtonKind.soft),
    ],
    'forms' => const [
      (
        operation: 'publish',
        label: 'Опубликовать',
        kind: RefButtonKind.primary,
      ),
      (operation: 'close', label: 'Закрыть', kind: RefButtonKind.ghost),
      (operation: 'analyze', label: 'Анализировать', kind: RefButtonKind.soft),
      (operation: 'fields', label: 'Добавить поле', kind: RefButtonKind.soft),
      (
        operation: 'submit',
        label: 'Отправить ответ',
        kind: RefButtonKind.primary,
      ),
    ],
    'tasks' => const [
      (operation: 'assign', label: 'Назначить', kind: RefButtonKind.soft),
      (
        operation: 'transition',
        label: 'Изменить статус',
        kind: RefButtonKind.primary,
      ),
    ],
    'schedule' => const [
      (operation: 'move', label: 'Перенести занятие', kind: RefButtonKind.soft),
      (
        operation: 'cancel',
        label: 'Отменить занятие',
        kind: RefButtonKind.danger,
      ),
    ],
    'assignments' => const [
      (
        operation: 'publish',
        label: 'Опубликовать',
        kind: RefButtonKind.primary,
      ),
      (
        operation: 'submissions',
        label: 'Добавить отправку',
        kind: RefButtonKind.soft,
      ),
    ],
    'submissions' => const [
      (
        operation: 'grade',
        label: 'Оценить работу',
        kind: RefButtonKind.primary,
      ),
      (
        operation: 'request-ai-feedback',
        label: 'Запросить AI-проверку',
        kind: RefButtonKind.soft,
      ),
    ],
    'exams' => const [
      (
        operation: 'publish',
        label: 'Опубликовать экзамен',
        kind: RefButtonKind.primary,
      ),
      (
        operation: 'results',
        label: 'Добавить результаты',
        kind: RefButtonKind.soft,
      ),
      (
        operation: 'results/import-csv',
        label: 'Импорт результатов CSV',
        kind: RefButtonKind.ghost,
      ),
    ],
    'contentFiles' => const [
      (
        operation: 'confirm',
        label: 'Подтвердить загрузку',
        kind: RefButtonKind.soft,
      ),
      (
        operation: 'new-version',
        label: 'Новая версия',
        kind: RefButtonKind.primary,
      ),
      (
        operation: 'approve-teacher',
        label: 'Одобрить учителем',
        kind: RefButtonKind.ghost,
      ),
      (
        operation: 'approve-manager',
        label: 'Одобрить менеджером',
        kind: RefButtonKind.primary,
      ),
      (
        operation: 'track-view',
        label: 'Зафиксировать просмотр',
        kind: RefButtonKind.ghost,
      ),
    ],
    'contentMaterials' => const [
      (operation: 'generate', label: 'Сгенерировать', kind: RefButtonKind.soft),
      (
        operation: 'publish',
        label: 'Опубликовать',
        kind: RefButtonKind.primary,
      ),
    ],
    'printAgents' => const [
      (
        operation: 'revoke',
        label: 'Отозвать агент',
        kind: RefButtonKind.danger,
      ),
    ],
    'invoices' => const [
      (
        operation: 'payment-plan',
        label: 'План оплаты',
        kind: RefButtonKind.soft,
      ),
      (operation: 'void', label: 'Аннулировать', kind: RefButtonKind.danger),
    ],
    'expenses' => const [
      (operation: 'approve', label: 'Одобрить', kind: RefButtonKind.primary),
      (operation: 'reject', label: 'Отклонить', kind: RefButtonKind.danger),
      (operation: 'pay', label: 'Оплатить', kind: RefButtonKind.soft),
    ],
    'discounts' => const [
      (
        operation: 'deactivate',
        label: 'Деактивировать скидку',
        kind: RefButtonKind.danger,
      ),
    ],
    'cashierShifts' => const [
      (
        operation: 'close',
        label: 'Закрыть кассовую смену',
        kind: RefButtonKind.danger,
      ),
    ],
    'meetings' => const [
      (operation: 'respond', label: 'Ответить', kind: RefButtonKind.primary),
      (operation: 'cancel', label: 'Отменить', kind: RefButtonKind.danger),
    ],
    'rules' => const [
      (
        operation: 'acknowledge',
        label: 'Подтвердить ознакомление',
        kind: RefButtonKind.primary,
      ),
    ],
    'penalties' => const [
      (operation: 'waive', label: 'Снять взыскание', kind: RefButtonKind.soft),
    ],
    'placementTests' => const [
      (operation: 'generate', label: 'Сгенерировать', kind: RefButtonKind.soft),
      (operation: 'approve', label: 'Одобрить', kind: RefButtonKind.primary),
      (operation: 'reject', label: 'Отклонить', kind: RefButtonKind.danger),
      (
        operation: 'questions',
        label: 'Добавить вопрос',
        kind: RefButtonKind.soft,
      ),
      (
        operation: 'submit',
        label: 'Отправить тест',
        kind: RefButtonKind.primary,
      ),
    ],
    'placementProposals' => const [
      (operation: 'accept', label: 'Принять', kind: RefButtonKind.primary),
      (operation: 'reject', label: 'Отклонить', kind: RefButtonKind.danger),
    ],
    'placementAttempts' => const [
      (
        operation: 'submit',
        label: 'Отправить попытку',
        kind: RefButtonKind.primary,
      ),
      (
        operation: 'mark-writing',
        label: 'Проверить writing',
        kind: RefButtonKind.soft,
      ),
      (
        operation: 'mark-writing-manual',
        label: 'Ручная оценка',
        kind: RefButtonKind.ghost,
      ),
    ],
    'teachers' => const [
      (
        operation: 'prepare-salary',
        label: 'Подготовить зарплату',
        kind: RefButtonKind.primary,
      ),
    ],
    'payments' => const [
      (operation: 'allocate', label: 'Распределить', kind: RefButtonKind.soft),
      (
        operation: 'refund',
        label: 'Оформить возврат',
        kind: RefButtonKind.danger,
      ),
    ],
    'cards' => const [
      (
        operation: 'revoke',
        label: 'Отозвать карту',
        kind: RefButtonKind.danger,
      ),
    ],
    'achievements' => const [
      (
        operation: 'grant',
        label: 'Выдать достижение',
        kind: RefButtonKind.primary,
      ),
    ],
    'covers' => const [
      (
        operation: 'assign',
        label: 'Назначить замену',
        kind: RefButtonKind.primary,
      ),
      (operation: 'open-pool', label: 'Открыть пул', kind: RefButtonKind.soft),
      (operation: 'claim', label: 'Принять', kind: RefButtonKind.ghost),
      (operation: 'cancel', label: 'Отменить', kind: RefButtonKind.danger),
      (
        operation: 'reject',
        label: 'Отклонить замену',
        kind: RefButtonKind.danger,
      ),
    ],
    'loans' => const [
      (operation: 'repay', label: 'Погасить', kind: RefButtonKind.primary),
    ],
    'campaignTemplates' => const [
      (operation: 'generate', label: 'Сгенерировать', kind: RefButtonKind.soft),
    ],
    'campaigns' => const [
      (
        operation: 'send',
        label: 'Отправить кампанию',
        kind: RefButtonKind.primary,
      ),
    ],
    'sales' => const [
      (
        operation: 'refund',
        label: 'Возврат продажи',
        kind: RefButtonKind.danger,
      ),
    ],
    _ => const [],
  };

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
      ['Посещаемость', '${group.analytics['attendance_percent'] ?? 0}%'],
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
      csvRecords('Посещаемость', group.attendance),
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
        '${section('Посещаемость', group.attendance)}'
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
    final canMutate = _canMutateResource(context, widget.resource);
    final actions = canMutate ? _recordActions() : const [];
    final canUpdate =
        canMutate && kApiUpdatableResources.contains(widget.resource);
    final canDelete =
        canMutate && kApiDeletableResources.contains(widget.resource);
    return SfTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: _LiveShell(
            title: widget.title,
            eyebrow: tx(
              context,
              uz: 'BATAFSIL MA’LUMOT',
              ru: 'ПОДРОБНАЯ ИНФОРМАЦИЯ',
              en: 'DETAILS',
            ),
            subtitle: tx(
              context,
              uz: 'Asosiy ma’lumotlar, bog‘lanishlar va amallar',
              ru: 'Основные данные, связи и доступные действия',
              en: 'Core information, relationships and available actions',
            ),
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
              if (actions.isNotEmpty || canUpdate || canDelete) ...[
                RefSectionHeader(
                  title: 'Действия',
                  subtitle: 'Доступные операции для этой записи',
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (canUpdate)
                      RefButton(
                        label: 'Изменить',
                        kind: RefButtonKind.soft,
                        onPressed: _acting ? null : _updateRecord,
                      ),
                    if (canDelete)
                      RefButton(
                        label: 'Удалить',
                        kind: RefButtonKind.danger,
                        onPressed: _acting ? null : _deleteRecord,
                      ),
                    if (widget.resource == 'teachers')
                      RefButton(
                        key: const ValueKey('teacher-payout-policy'),
                        label: 'Политика выплат',
                        kind: RefButtonKind.soft,
                        onPressed: _acting ? null : _editTeacherPayoutPolicy,
                      ),
                    for (final action in actions)
                      RefButton(
                        label: action.label,
                        kind: action.kind,
                        onPressed: _acting
                            ? null
                            : () => _runRecordAction(
                                action.operation,
                                action.label,
                              ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
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
                    'Посещаемость': '${group.analytics['attendance_percent']}%',
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
                  title: 'Посещаемость tarixi',
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
                  title: 'Bo‘lim jamoasi',
                  value: {
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
                    ? tx(
                        context,
                        uz: 'Qo‘shimcha ma’lumot',
                        ru: 'Дополнительная информация',
                        en: 'Additional information',
                      )
                    : tx(
                        context,
                        uz: 'To‘lov ma’lumotlari',
                        ru: 'Информация о платеже',
                        en: 'Payment information',
                      ),
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
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: RefRefreshStatus(
                    label: tx(
                      context,
                      uz: 'Ma’lumotlar yangilanmoqda',
                      ru: 'Данные обновляются',
                      en: 'Refreshing data',
                    ),
                  ),
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
  Widget build(BuildContext context) => ApiDataCard(title: title, value: value);
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
              tx(
                context,
                uz: 'Ma’lumotlarni yangilab bo‘lmadi',
                ru: 'Не удалось обновить данные',
                en: 'Could not update data',
              ),
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
              label: tx(
                context,
                uz: 'Qayta urinish',
                ru: 'Повторить',
                en: 'Try again',
              ),
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
    return RefEmptyState(
      icon: icon,
      title: tx(
        context,
        uz: 'Hozircha ma’lumot yo‘q',
        ru: 'Пока нет данных',
        en: 'Nothing here yet',
      ),
      message: message,
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
  DateTimeRange? _customRange;
  bool _refreshing = false;
  bool _exporting = false;
  bool _acceptingPayment = false;
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
    final custom = _customRange;
    if (custom != null) {
      return (
        from: DateTime(custom.start.year, custom.start.month, custom.start.day),
        to: DateTime(
          custom.end.year,
          custom.end.month,
          custom.end.day,
          23,
          59,
          59,
        ),
      );
    }
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

  String _periodLabel() {
    final custom = _customRange;
    if (custom != null) {
      return '${_dateLabel(custom.start)} — ${_dateLabel(custom.end)}';
    }
    return switch (_period) {
      _ReportPeriod.week => '7 kun',
      _ReportPeriod.month => '1 oy',
      _ReportPeriod.quarter => '3 oy',
      _ReportPeriod.year => '12 oy',
    };
  }

  Future<void> _pickCustomRange() async {
    final value = await showRefDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customRange,
      title: 'Период',
    );
    if (value != null && mounted) setState(() => _customRange = value);
  }

  String _dateLabel(DateTime? value) {
    if (value == null) return 'Sana ko‘rsatilmagan';
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }

  num _amount(Map<String, dynamic> row) =>
      _number(row, const [
        'amount_uzs',
        'total_uzs',
        'amount',
        'paid_amount',
        'total',
        'sum',
        'value',
      ]) ??
      0;

  Future<void> _acceptCashPayment() async {
    if (_acceptingPayment) return;
    final controller = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert({
        'student_id': '',
        'amount': 0,
        'payment_method_id': '',
        'comment': '',
      }),
    );
    String? validation;
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Принять оплату'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Команда будет отправлена в POST /api/v1/payments/cash/. '
                  'Проверьте идентификаторы и сумму.',
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('live-cash-payment-json'),
                  controller: controller,
                  minLines: 7,
                  maxLines: 12,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    labelText: 'Данные оплаты · JSON',
                    errorText: validation,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  final decoded = jsonDecode(controller.text);
                  if (decoded is! Map) throw const FormatException();
                  Navigator.of(context).pop(Map<String, dynamic>.from(decoded));
                } on FormatException {
                  setDialogState(
                    () => validation = 'Введите корректный JSON-объект',
                  );
                }
              },
              child: const Text('Принять'),
            ),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
    if (payload == null || !mounted) return;
    setState(() {
      _acceptingPayment = true;
      _error = null;
    });
    try {
      await ApiScope.of(context).action(
        'POST',
        '/api/v1/payments/cash/',
        body: payload,
        refreshResources: const ['payments', 'invoices'],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Оплата принята сервером')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = _liveApiError(error));
    } finally {
      if (mounted) setState(() => _acceptingPayment = false);
    }
  }

  List<Map<String, dynamic>> _refundsFrom(
    List<Map<String, dynamic>> payments,
  ) => payments
      .map((payment) {
        final refunded = _number(payment, const [
          'refunded_amount',
          'refund_amount',
          'amount_refunded',
        ]);
        final status = _text(
          _value(payment, const ['status', 'payment_status', 'state']),
          empty: '',
        ).toLowerCase();
        if ((refunded ?? 0) <= 0 &&
            status != 'refunded' &&
            status != 'reversed') {
          return null;
        }
        return <String, dynamic>{
          ...payment,
          if (refunded != null && refunded > 0) 'amount': refunded,
          'record_type': 'refund',
        };
      })
      .whereType<Map<String, dynamic>>()
      .toList(growable: false);

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
    final allPayments = session.records('payments');
    final payments = _inPeriod(allPayments, settledPaymentsOnly: true);
    final invoices = _inPeriod(session.records('invoices'));
    final expenses = _inPeriod(session.records('expenses'));
    final refunds = _inPeriod(_refundsFrom(allPayments));
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
      eyebrow: tx(
        context,
        uz: 'MOLIYAVIY HISOBOT · ${_periodLabel().toUpperCase()}',
        ru: 'ФИНАНСОВЫЙ ОТЧЁТ · ${_periodLabel().toUpperCase()}',
        en: 'FINANCIAL REPORT · ${_periodLabel().toUpperCase()}',
      ),
      subtitle: 'To‘lovlar, xarajatlar, statistika, grafika va eksport',
      loading: _refreshing,
      onRefresh: _refresh,
      body: [
        RefButton(
          label: _acceptingPayment ? 'Оплата отправляется…' : 'Принять оплату',
          leading: Icons.point_of_sale_rounded,
          block: true,
          onPressed: _acceptingPayment ? null : _acceptCashPayment,
        ),
        const SizedBox(height: 12),
        RefSegmentedControl<_ReportPeriod>(
          values: _ReportPeriod.values,
          selected: _period,
          labelOf: (value) => switch (value) {
            _ReportPeriod.week => '7 kun',
            _ReportPeriod.month => 'Oy',
            _ReportPeriod.quarter => '3 oy',
            _ReportPeriod.year => 'Yil',
          },
          onChanged: (value) => setState(() {
            _period = value;
            _customRange = null;
          }),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: RefButton(
                label: _customRange == null
                    ? 'От — до'
                    : '${_dateLabel(_customRange!.start)} — ${_dateLabel(_customRange!.end)}',
                leading: Icons.date_range_rounded,
                onPressed: _pickCustomRange,
              ),
            ),
            if (_customRange != null) ...[
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'Сбросить диапазон',
                onPressed: () => setState(() => _customRange = null),
                icon: const Icon(Icons.restart_alt_rounded),
              ),
            ],
          ],
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
  bool _refreshing = false;
  bool _markingAll = false;
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
        ApiScope.of(context).refresh('notifications', force: true),
        ApiScope.of(context).refresh('unreadNotifications', force: true),
      ]);
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

    final rawData = apiPresentationValue(record['data']);
    final data = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : const <String, dynamic>{};
    final effective = <String, dynamic>{...data, ...record};
    final explicit = _text(
      _value(effective, const ['route', 'screen', 'target', 'section']),
      empty: '',
    ).replaceFirst(RegExp(r'^/+'), '');
    if (explicit.isNotEmpty && roleCanNavigate(role, explicit)) {
      return explicit;
    }
    final source = [
      _value(record, const [
        'route',
        'screen',
        'target',
        'section',
        'entity_type',
        'type',
        'category',
      ]),
      _value(effective, const [
        'route',
        'screen',
        'target',
        'section',
        'entity_type',
        'type',
        'category',
        'event_type',
        'thread_id',
        'message_id',
      ]),
      _value(effective, const ['title', 'message', 'body']),
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
    // Some backend events are informational and intentionally do not publish
    // a destination. Marking them read is the complete action; opening the
    // generic JSON detail page produced an empty-looking screen for users.
  }

  Future<void> _markAllRead() async {
    if (_markingAll) return;
    setState(() {
      _markingAll = true;
      _error = null;
    });
    try {
      await ApiScope.of(context).action(
        'POST',
        '/api/v1/notifications/read-all/',
        refreshResources: const ['notifications', 'unreadNotifications'],
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = _liveApiError(error));
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ApiScope.of(context);
    final all = session.records('notifications');
    final unreadTotal = all.where((record) => !_isRead(record)).length;
    final filtered = _unreadOnly
        ? all.where((record) => !_isRead(record)).toList(growable: false)
        : all;
    final unread = filtered
        .where((record) => !_isRead(record))
        .toList(growable: false);
    final read = filtered.where(_isRead).toList(growable: false);
    return _LiveShell(
      title: tx(
        context,
        uz: 'Bildirishnomalar',
        ru: 'Уведомления',
        en: 'Notifications',
      ),
      eyebrow: tx(
        context,
        uz: 'BILDIRISHNOMALAR · ${session.totalFor('notifications')}',
        ru: 'УВЕДОМЛЕНИЯ · ${session.totalFor('notifications')}',
        en: 'NOTIFICATIONS · ${session.totalFor('notifications')}',
      ),
      subtitle: unreadTotal == 0
          ? tx(
              context,
              uz: 'Yangi bildirishnomalar yo‘q',
              ru: 'Новых уведомлений нет',
              en: 'No new notifications',
            )
          : tx(
              context,
              uz: '$unreadTotal ta yangi bildirishnoma',
              ru: 'Новых уведомлений: $unreadTotal',
              en: '$unreadTotal new notifications',
            ),
      loading: _refreshing,
      onRefresh: _refresh,
      body: [
        if (unreadTotal > 0) ...[
          RefButton(
            label: _markingAll
                ? tx(
                    context,
                    uz: 'Yangilanmoqda…',
                    ru: 'Обновление…',
                    en: 'Updating…',
                  )
                : tx(
                    context,
                    uz: 'Barchasini o‘qish',
                    ru: 'Прочитать все',
                    en: 'Mark all as read',
                  ),
            kind: RefButtonKind.soft,
            leading: Icons.done_all_rounded,
            block: true,
            onPressed: _markingAll ? null : _markAllRead,
          ),
          const SizedBox(height: 10),
        ],
        if (all.isNotEmpty) ...[
          SegmentedButton<bool>(
            segments: [
              ButtonSegment<bool>(
                value: true,
                label: Text(tx(context, uz: 'Yangi', ru: 'Новые', en: 'New')),
                icon: const Icon(Icons.mark_email_unread_outlined),
              ),
              ButtonSegment<bool>(
                value: false,
                label: Text(
                  tx(context, uz: 'Tarix', ru: 'История', en: 'History'),
                ),
                icon: const Icon(Icons.history_rounded),
              ),
            ],
            selected: {_unreadOnly},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => setState(() {
              _unreadOnly = selection.first;
            }),
          ),
          const SizedBox(height: 12),
        ],
        if (_error != null) _LiveError(message: _error!, onRetry: _refresh),
        if (all.isEmpty && !_refreshing && _error == null)
          _LiveEmpty(
            icon: Icons.notifications_off_outlined,
            message: tx(
              context,
              uz: 'Hozircha bildirishnomalar yo‘q.',
              ru: 'Уведомлений пока нет.',
              en: 'No notifications yet.',
            ),
          ),
        if (all.isNotEmpty && filtered.isEmpty && !_refreshing)
          _LiveEmpty(
            icon: Icons.done_all_rounded,
            message: tx(
              context,
              uz: 'Yangi bildirishnoma yo‘q. O‘qilganlari tarixda saqlanadi.',
              ru: 'Новых уведомлений нет. Прочитанные сохранены в истории.',
              en: 'No new notifications. Read items are saved in history.',
            ),
          ),
        if (unread.isNotEmpty) ...[
          RefSectionHeader(
            title: tx(
              context,
              uz: 'O‘qilmagan',
              ru: 'Непрочитанные',
              en: 'Unread',
            ),
            subtitle: tx(
              context,
              uz: '${unread.length} ta yangi',
              ru: 'Новых: ${unread.length}',
              en: '${unread.length} new',
            ),
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
            title: tx(context, uz: 'O‘qilgan', ru: 'Прочитанные', en: 'Read'),
            subtitle: tx(
              context,
              uz: '${read.length} ta bildirishnoma',
              ru: 'Уведомлений: ${read.length}',
              en: '${read.length} notifications',
            ),
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
      ],
    );
  }
}

Map<String, dynamic> _notificationEffectiveRecord(Map<String, dynamic> record) {
  final presented = apiPresentationValue(record['data']);
  final nested = presented is Map
      ? Map<String, dynamic>.from(presented)
      : const <String, dynamic>{};
  return <String, dynamic>{...nested, ...record};
}

String _notificationKind(Map<String, dynamic> record) => _text(
  _value(_notificationEffectiveRecord(record), const [
    'type',
    'category',
    'event_type',
    'kind',
  ]),
  empty: 'general',
).toLowerCase();

bool _notificationKindContains(String kind, Iterable<String> words) =>
    words.any(kind.contains);

String _notificationKindLabel(BuildContext context, String kind) {
  if (_notificationKindContains(kind, const [
    'payment',
    'finance',
    'invoice',
  ])) {
    return tx(context, uz: 'To‘lov', ru: 'Платёж', en: 'Payment');
  }
  if (_notificationKindContains(kind, const ['attendance', 'davomat'])) {
    return tx(context, uz: 'Davomat', ru: 'Посещаемость', en: 'Attendance');
  }
  if (_notificationKindContains(kind, const ['message', 'thread', 'chat'])) {
    return tx(context, uz: 'Xabar', ru: 'Сообщение', en: 'Message');
  }
  if (_notificationKindContains(kind, const ['risk', 'anomal', 'signal'])) {
    return tx(context, uz: 'Xavf', ru: 'Риск', en: 'Risk');
  }
  if (_notificationKindContains(kind, const ['approval', 'approve'])) {
    return tx(context, uz: 'Tasdiqlash', ru: 'Согласование', en: 'Approval');
  }
  if (_notificationKindContains(kind, const ['student'])) {
    return tx(context, uz: 'O‘quvchi', ru: 'Ученик', en: 'Student');
  }
  if (_notificationKindContains(kind, const ['teacher'])) {
    return tx(context, uz: 'O‘qituvchi', ru: 'Преподаватель', en: 'Teacher');
  }
  return tx(context, uz: 'Tizim', ru: 'Система', en: 'System');
}

IconData _notificationKindIcon(String kind) {
  if (_notificationKindContains(kind, const [
    'payment',
    'finance',
    'invoice',
  ])) {
    return Icons.payments_rounded;
  }
  if (_notificationKindContains(kind, const ['attendance', 'davomat'])) {
    return Icons.how_to_reg_rounded;
  }
  if (_notificationKindContains(kind, const ['teacher'])) {
    return Icons.workspace_premium_rounded;
  }
  if (_notificationKindContains(kind, const ['student'])) {
    return Icons.groups_rounded;
  }
  if (_notificationKindContains(kind, const ['approval', 'approve'])) {
    return Icons.task_alt_rounded;
  }
  if (_notificationKindContains(kind, const ['message', 'thread', 'chat'])) {
    return Icons.chat_bubble_rounded;
  }
  if (_notificationKindContains(kind, const ['risk', 'anomal', 'signal'])) {
    return Icons.warning_amber_rounded;
  }
  return Icons.notifications_rounded;
}

Color _notificationKindColor(SfColors colors, String kind) {
  if (_notificationKindContains(kind, const [
    'payment',
    'finance',
    'invoice',
  ])) {
    return colors.success;
  }
  if (_notificationKindContains(kind, const ['risk', 'anomal', 'signal'])) {
    return colors.danger;
  }
  if (_notificationKindContains(kind, const ['approval', 'approve'])) {
    return colors.warn;
  }
  if (_notificationKindContains(kind, const ['message', 'thread', 'chat'])) {
    return colors.ai;
  }
  return colors.primary;
}

String _notificationTitle(
  BuildContext context,
  Map<String, dynamic> record,
  String kind,
) {
  final effective = _notificationEffectiveRecord(record);
  final explicit = _text(
    _value(effective, const ['title', 'subject', 'heading', 'name']),
    empty: '',
  ).trim();
  if (explicit.isNotEmpty && explicit != '—') return explicit;
  if (_notificationKindContains(kind, const [
    'payment',
    'finance',
    'invoice',
  ])) {
    return tx(
      context,
      uz: 'Yangi to‘lov',
      ru: 'Новый платёж',
      en: 'New payment',
    );
  }
  if (_notificationKindContains(kind, const ['message', 'thread', 'chat'])) {
    return tx(
      context,
      uz: 'Yangi xabar',
      ru: 'Новое сообщение',
      en: 'New message',
    );
  }
  if (_notificationKindContains(kind, const ['attendance', 'davomat'])) {
    return tx(
      context,
      uz: 'Davomat yangilandi',
      ru: 'Посещаемость обновлена',
      en: 'Attendance updated',
    );
  }
  if (_notificationKindContains(kind, const ['risk', 'anomal', 'signal'])) {
    return tx(
      context,
      uz: 'Yangi xavf signali',
      ru: 'Новый сигнал риска',
      en: 'New risk signal',
    );
  }
  return tx(
    context,
    uz: 'Bildirishnoma',
    ru: 'Уведомление',
    en: 'Notification',
  );
}

String _notificationBody(BuildContext context, Map<String, dynamic> record) {
  final effective = _notificationEffectiveRecord(record);
  final explicit = _text(
    _value(effective, const ['message', 'body', 'description', 'content']),
    empty: '',
  ).trim();
  if (explicit.isNotEmpty && explicit != '—') return explicit;
  final facts = <String>[
    for (final keys in const <List<String>>[
      ['student_name', 'student'],
      ['group_name', 'group'],
      ['payer_name', 'payer'],
      ['amount', 'amount_uzs'],
    ])
      if (_text(_value(effective, keys), empty: '').trim() case final value
          when value.isNotEmpty && value != '—')
        value,
  ];
  if (facts.isNotEmpty) return facts.join(' · ');
  return tx(
    context,
    uz: 'Tafsilotlarni ko‘rish uchun bildirishnomani oching.',
    ru: 'Откройте уведомление, чтобы посмотреть подробности.',
    en: 'Open the notification to view details.',
  );
}

String _notificationTime(BuildContext context, Map<String, dynamic> record) {
  final effective = _notificationEffectiveRecord(record);
  final raw = _text(
    _value(effective, const ['created_at', 'sent_at', 'timestamp', 'date']),
    empty: '',
  ).trim();
  if (raw.isEmpty || raw == '—') {
    return tx(
      context,
      uz: 'Vaqt ko‘rsatilmagan',
      ru: 'Время не указано',
      en: 'Time not specified',
    );
  }
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final local = parsed.toLocal();
  final now = DateTime.now();
  final difference = now.difference(local);
  if (!difference.isNegative && difference < const Duration(minutes: 1)) {
    return tx(context, uz: 'Hozir', ru: 'Сейчас', en: 'Now');
  }
  if (!difference.isNegative && difference < const Duration(hours: 1)) {
    final minutes = difference.inMinutes;
    return tx(
      context,
      uz: '$minutes daqiqa oldin',
      ru: '$minutes мин назад',
      en: '$minutes min ago',
    );
  }
  if (!difference.isNegative && difference < const Duration(hours: 6)) {
    final hours = difference.inHours;
    return tx(
      context,
      uz: '$hours soat oldin',
      ru: '$hours ч назад',
      en: '$hours h ago',
    );
  }
  String two(int value) => value.toString().padLeft(2, '0');
  final clock = '${two(local.hour)}:${two(local.minute)}';
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(local.year, local.month, local.day);
  if (date == today) {
    return tx(
      context,
      uz: 'Bugun $clock',
      ru: 'Сегодня, $clock',
      en: 'Today, $clock',
    );
  }
  if (date == today.subtract(const Duration(days: 1))) {
    return tx(
      context,
      uz: 'Kecha $clock',
      ru: 'Вчера, $clock',
      en: 'Yesterday, $clock',
    );
  }
  return '${two(local.day)}.${two(local.month)}.${local.year} · $clock';
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

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final kind = _notificationKind(record);
    final type = _notificationKindLabel(context, kind);
    final color = _notificationKindColor(c, kind);
    final time = _notificationTime(context, record);
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
                color: color.withValues(alpha: .13),
                borderRadius: RefRadius.md,
              ),
              child: SizedBox(
                width: 42,
                height: 42,
                child: Icon(_notificationKindIcon(kind), color: color),
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
                            _notificationTitle(context, record, kind),
                            empty: tx(
                              context,
                              uz: 'Bildirishnoma',
                              ru: 'Уведомление',
                              en: 'Notification',
                            ),
                          ),
                          maxLines: 2,
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
                    _text(_notificationBody(context, record)),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: RefType.ui(size: 11.5, color: c.muted, height: 1.35),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      RefPill(
                        label: type,
                        tone:
                            _notificationKindContains(kind, const [
                              'risk',
                              'anomal',
                              'signal',
                            ])
                            ? RefPillTone.danger
                            : _notificationKindContains(kind, const [
                                'payment',
                                'finance',
                                'invoice',
                              ])
                            ? RefPillTone.success
                            : RefPillTone.primary,
                      ),
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
