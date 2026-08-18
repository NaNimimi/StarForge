import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'api_client.dart';
import 'api_store_adapter.dart';
import 'data.dart';
import 'i18n.dart';
import 'reference_ui.dart';
import 'screens.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Mobile compositions of the React console pages.  These pages only project
/// the existing [AppStore] state: their filters, mutation callbacks and detail
/// routes deliberately stay in the original Flutter feature layer.

class WebGroupsPage extends StatefulWidget {
  const WebGroupsPage({super.key});

  @override
  State<WebGroupsPage> createState() => _WebGroupsPageState();
}

class _WebGroupsPageState extends State<WebGroupsPage> {
  final _search = TextEditingController();
  String _query = '';
  int _status = 0;
  String _branch = '';
  String _teacher = '';
  String _level = '';
  int _attendance = 0;
  int _debt = 0;
  DateTimeRange? _range;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _groupMatchesRange(AppStore store, GroupInfo group) {
    final range = _range;
    if (range == null) return true;
    final end = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
      23,
      59,
      59,
    );
    return store.students
        .where((student) => student.group == group.name)
        .map((student) => _webDate(studentProfile(student).enrolled))
        .whereType<DateTime>()
        .any((date) => !date.isBefore(range.start) && !date.isAfter(end));
  }

  Future<void> _pickRange() async {
    final value = await showRefDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: _range,
      title: tx(
        context,
        uz: 'O‘quvchilar boshlagan davr',
        ru: 'Период начала обучения',
        en: 'Education start period',
      ),
    );
    if (value != null && mounted) setState(() => _range = value);
  }

  Future<void> _openFilters({
    required List<String> branches,
    required List<String> teachers,
    required List<String> levels,
  }) async {
    final c = SfTheme.of(context);
    var status = _status;
    var branch = _branch;
    var teacher = _teacher;
    var level = _level;
    var attendance = _attendance;
    var debt = _debt;

    final shouldApply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SfTheme(
        colors: c,
        child: StatefulBuilder(
          builder: (context, updateSheet) {
            InputDecoration decoration(String label) => InputDecoration(
              labelText: label,
              filled: true,
              fillColor: c.surface2,
              border: OutlineInputBorder(
                borderRadius: RefRadius.md,
                borderSide: BorderSide(color: c.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: RefRadius.md,
                borderSide: BorderSide(color: c.border),
              ),
            );

            return SafeArea(
              top: false,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .88,
                ),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(26),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 8, 8),
                      child: RefSectionHeader(
                        title: tx(
                          context,
                          uz: 'Guruh filtrlari',
                          ru: 'Фильтры групп',
                          en: 'Group filters',
                        ),
                        subtitle: tx(
                          context,
                          uz: 'Kerakli parametrlarni tanlang',
                          ru: 'Выберите нужные параметры',
                          en: 'Choose the required parameters',
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
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                        children: [
                          DropdownButtonFormField<int>(
                            key: const ValueKey('groups-filter-status'),
                            initialValue: status,
                            decoration: decoration(
                              tx(
                                context,
                                uz: 'Holat',
                                ru: 'Статус',
                                en: 'Status',
                              ),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 0,
                                child: Text(tr(context, 'f_all')),
                              ),
                              DropdownMenuItem(
                                value: 1,
                                child: Text(tr(context, 'status_active')),
                              ),
                              DropdownMenuItem(
                                value: 2,
                                child: Text(tr(context, 'status_paused')),
                              ),
                              DropdownMenuItem(
                                value: 3,
                                child: Text(tr(context, 'f_debtor')),
                              ),
                            ],
                            onChanged: (value) =>
                                updateSheet(() => status = value ?? 0),
                          ),
                          const SizedBox(height: 12),
                          _WebFilterDropdown(
                            label: tr(context, 'filter_branch'),
                            value: branch,
                            values: branches,
                            decoration: decoration(
                              tr(context, 'filter_branch'),
                            ),
                            onChanged: (value) =>
                                updateSheet(() => branch = value),
                          ),
                          const SizedBox(height: 12),
                          _WebFilterDropdown(
                            label: tr(context, 'group_teacher'),
                            value: teacher,
                            values: teachers,
                            decoration: decoration(
                              tr(context, 'group_teacher'),
                            ),
                            onChanged: (value) =>
                                updateSheet(() => teacher = value),
                          ),
                          const SizedBox(height: 12),
                          _WebFilterDropdown(
                            label: tr(context, 'filter_level'),
                            value: level,
                            values: levels,
                            decoration: decoration(tr(context, 'filter_level')),
                            onChanged: (value) =>
                                updateSheet(() => level = value),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            key: const ValueKey('groups-filter-attendance'),
                            initialValue: attendance,
                            decoration: decoration(
                              tr(context, 'stat_attendance'),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 0,
                                child: Text(tr(context, 'f_all')),
                              ),
                              const DropdownMenuItem(
                                value: 1,
                                child: Text('90%+'),
                              ),
                              const DropdownMenuItem(
                                value: 2,
                                child: Text('75–89%'),
                              ),
                              DropdownMenuItem(
                                value: 3,
                                child: Text(
                                  tx(
                                    context,
                                    uz: '75% gacha',
                                    ru: 'До 75%',
                                    en: 'Below 75%',
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) =>
                                updateSheet(() => attendance = value ?? 0),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            key: const ValueKey('groups-filter-debt'),
                            initialValue: debt,
                            decoration: decoration(tr(context, 'stat_debt')),
                            items: [
                              DropdownMenuItem(
                                value: 0,
                                child: Text(tr(context, 'f_all')),
                              ),
                              DropdownMenuItem(
                                value: 1,
                                child: Text(
                                  tx(
                                    context,
                                    uz: 'Qarzsiz',
                                    ru: 'Без долга',
                                    en: 'No debt',
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 2,
                                child: Text(
                                  tx(
                                    context,
                                    uz: 'Qarz bor',
                                    ru: 'Есть долг',
                                    en: 'Has debt',
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) =>
                                updateSheet(() => debt = value ?? 0),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              key: const ValueKey('groups-reset-filters'),
                              onPressed: () => updateSheet(() {
                                status = 0;
                                branch = '';
                                teacher = '';
                                level = '';
                                attendance = 0;
                                debt = 0;
                              }),
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
                              key: const ValueKey('groups-apply-filters'),
                              onPressed: () =>
                                  Navigator.of(sheetContext).pop(true),
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
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    if (shouldApply != true || !mounted) return;
    setState(() {
      _status = status;
      _branch = branch;
      _teacher = teacher;
      _level = level;
      _attendance = attendance;
      _debt = debt;
    });
  }

  Future<void> _openStudents(
    AppStore store,
    List<GroupInfo> selectedGroups,
  ) async {
    final names = selectedGroups.map((group) => group.name).toSet();
    final students = store.students
        .where((student) => names.contains(student.group))
        .toList();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final c = SfTheme.of(context);
        return SfTheme(
          colors: c,
          child: DraggableScrollableSheet(
            initialChildSize: .72,
            minChildSize: .45,
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
                    padding: const EdgeInsets.fromLTRB(18, 16, 8, 8),
                    child: RefSectionHeader(
                      title: tx(
                        context,
                        uz: 'Tanlangan guruh o‘quvchilari',
                        ru: 'Ученики выбранных групп',
                        en: 'Students in selected groups',
                      ),
                      subtitle:
                          '${students.length} ${tr(context, 'unit_student')}',
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
                  ),
                  Expanded(
                    child: ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                      itemCount: students.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 7),
                      itemBuilder: (_, index) {
                        final student = students[index];
                        return RefStatusTile(
                          icon: Icons.person_outline_rounded,
                          title: student.name,
                          subtitle:
                              '${student.group} · ${tr(context, 'stat_attendance')} ${student.attendance}%',
                          tone: student.debt > 0
                              ? RefMetricTone.warning
                              : RefMetricTone.success,
                          onTap: () => Navigator.of(sheetContext).push(
                            sfPageRoute(
                              StudentDetailScreen(student: student, colors: c),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final store = AppScope.of(context);
    final groups = _groupRows(store);
    final branches = groups.map((group) => group.branch).toSet().toList()
      ..sort();
    final teachers = groups.map((group) => group.teacher).toSet().toList()
      ..sort();
    final levels = groups.map((group) => group.level).toSet().toList()..sort();
    final filtered = groups.where((group) {
      final q = _query.toLowerCase();
      final statusOk = switch (_status) {
        1 => group.status == 'active',
        2 => group.status == 'paused',
        3 => group.debtors > 0,
        _ => true,
      };
      final attendanceOk = switch (_attendance) {
        1 => group.avgAtt >= 90,
        2 => group.avgAtt >= 75 && group.avgAtt < 90,
        3 => group.avgAtt < 75,
        _ => true,
      };
      final debtOk = switch (_debt) {
        1 => group.debtors == 0,
        2 => group.debtors > 0,
        _ => true,
      };
      return statusOk &&
          (_branch.isEmpty || group.branch == _branch) &&
          (_teacher.isEmpty || group.teacher == _teacher) &&
          (_level.isEmpty || group.level == _level) &&
          attendanceOk &&
          debtOk &&
          _groupMatchesRange(store, group) &&
          (q.isEmpty ||
              '${group.name} ${group.teacher} ${group.branch}'
                  .toLowerCase()
                  .contains(q));
    }).toList();
    final active = filtered.where((group) => group.status == 'active').length;
    final seats = filtered.fold<int>(0, (sum, group) => sum + group.count);
    final debtGroups = filtered.where((g) => g.debtors > 0).length;
    final filterCount =
        (_status == 0 ? 0 : 1) +
        (_branch.isEmpty ? 0 : 1) +
        (_teacher.isEmpty ? 0 : 1) +
        (_level.isEmpty ? 0 : 1) +
        (_attendance == 0 ? 0 : 1) +
        (_debt == 0 ? 0 : 1);
    return Material(
      color: c.bg,
      child: Column(
        children: [
          RefLargeHeader(
            eyebrow:
                '${groups.length} ${tr(context, 'unit_group').toUpperCase()}',
            title: tr(context, 'groups_title'),
            subtitle: tx(
              context,
              uz: 'Jadval, sig‘im va o‘quv jarayonini boshqaring',
              ru: 'Управляйте расписанием, местами и учебным процессом',
              en: 'Manage schedules, capacity and the learning process',
            ),
            actions: [
              RefIconAction(
                icon: Icons.add_rounded,
                tooltip: tr(context, 'create_group'),
                onPressed: () => Navigator.of(
                  context,
                ).push(sfPageRoute(GroupCreateScreen(colors: c))),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: RefMetricCard(
                        key: const ValueKey('groups-active-metric'),
                        label: tx(
                          context,
                          uz: 'Faol guruhlar',
                          ru: 'Активные группы',
                          en: 'Active groups',
                        ),
                        value: '$active',
                        icon: Icons.workspaces_rounded,
                        tone: RefMetricTone.primary,
                        compact: true,
                        uppercaseLabel: false,
                        onTap: () => setState(() => _status = 1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RefMetricCard(
                        key: const ValueKey('groups-students-metric'),
                        label: tr(context, 'branch_students'),
                        value: '$seats',
                        icon: Icons.groups_rounded,
                        tone: RefMetricTone.success,
                        compact: true,
                        uppercaseLabel: false,
                        onTap: () => _openStudents(store, filtered),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: RefMetricCard(
                    key: const ValueKey('groups-debt-metric'),
                    label: tx(
                      context,
                      uz: 'Qarzli guruhlar',
                      ru: 'Группы с долгом',
                      en: 'Groups with debt',
                    ),
                    value: '$debtGroups',
                    detail: tx(
                      context,
                      uz: 'Qarzli guruhlarni ko‘rish uchun bosing',
                      ru: 'Нажмите, чтобы показать группы с задолженностью',
                      en: 'Tap to show groups with outstanding debt',
                    ),
                    icon: Icons.flag_rounded,
                    tone: RefMetricTone.warning,
                    compact: true,
                    uppercaseLabel: false,
                    onTap: () => setState(() => _status = 3),
                  ),
                ),
                const SizedBox(height: 16),
                RefSearchField(
                  controller: _search,
                  hint: tr(context, 'groups_search'),
                  onChanged: (value) => setState(() {
                    _query = value;
                  }),
                  suffix: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () => setState(() {
                            _search.clear();
                            _query = '';
                          }),
                          icon: Icon(Icons.close_rounded, color: c.muted),
                        ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey('groups-open-filters'),
                        onPressed: () => _openFilters(
                          branches: branches,
                          teachers: teachers,
                          levels: levels,
                        ),
                        icon: Icon(
                          filterCount == 0
                              ? Icons.tune_rounded
                              : Icons.filter_alt_rounded,
                        ),
                        label: Text(
                          filterCount == 0
                              ? tx(
                                  context,
                                  uz: 'Filtrlar',
                                  ru: 'Фильтры',
                                  en: 'Filters',
                                )
                              : tx(
                                  context,
                                  uz: 'Filtrlar · $filterCount',
                                  ru: 'Фильтры · $filterCount',
                                  en: 'Filters · $filterCount',
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey('groups-date-range'),
                        onPressed: _pickRange,
                        icon: const Icon(Icons.date_range_rounded),
                        label: Text(
                          _range == null
                              ? tx(
                                  context,
                                  uz: 'Dan — gacha',
                                  ru: 'От — до',
                                  en: 'From — to',
                                )
                              : '${_webShort(_range!.start)} — ${_webShort(_range!.end)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (_range != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        key: const ValueKey('groups-reset-date-range'),
                        tooltip: tx(
                          context,
                          uz: 'Davrni tiklash',
                          ru: 'Сбросить период',
                          en: 'Reset period',
                        ),
                        onPressed: () => setState(() => _range = null),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                RefSectionHeader(
                  title: tr(context, 'groups_title'),
                  subtitle: tx(
                    context,
                    uz: '${filtered.length} ta mos natija',
                    ru: '${filtered.length} результатов',
                    en: '${filtered.length} matching results',
                  ),
                ),
                const SizedBox(height: 8),
                if (filtered.isEmpty)
                  _WebEmpty(
                    icon: Icons.workspaces_outline,
                    text: tx(
                      context,
                      uz: 'Guruh topilmadi',
                      ru: 'Группы не найдены',
                      en: 'No groups found',
                    ),
                  )
                else
                  for (var index = 0; index < filtered.length; index++) ...[
                    RefStaggeredReveal(
                      order: index,
                      child: _WebGroupCard(group: filtered[index]),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

DateTime? _webDate(String value) {
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

String _webShort(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';

class _WebFilterDropdown extends StatelessWidget {
  const _WebFilterDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.decoration,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> values;
  final InputDecoration decoration;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: decoration,
        items: [
          DropdownMenuItem(value: '', child: Text(tr(context, 'f_all'))),
          for (final item in values)
            DropdownMenuItem(value: item, child: Text(item)),
        ],
        onChanged: (next) => onChanged(next ?? ''),
      ),
    );
  }
}

List<GroupInfo> _groupRows(AppStore store) {
  final buckets = <String, List<Student>>{};
  for (final student in store.students) {
    buckets.putIfAbsent(student.group, () => []).add(student);
  }
  final groups = <GroupInfo>[];
  var position = 0;
  for (final entry in buckets.entries) {
    final students = entry.value;
    final first = students.first;
    final profile = studentProfile(first);
    final attendance =
        (students.fold<int>(0, (sum, item) => sum + item.attendance) /
                students.length)
            .round();
    const schedules = [
      'Du · Cho · Ju · 10:00',
      'Se · Pa · Sha · 14:00',
      'Du · Cho · Ju · 16:00',
    ];
    groups.add(
      GroupInfo(
        entry.key,
        profile.branch,
        profile.level,
        studentTeacher(first),
        schedules[position++ % schedules.length],
        students.length,
        attendance,
        students.where((student) => student.debt > 0).length,
      ),
    );
  }
  for (final group in store.extraGroups) {
    groups.add(
      GroupInfo.withStatus(
        group.name,
        group.branch,
        group.level,
        group.teacher,
        group.schedule,
        0,
        100,
        0,
        group.status,
      ),
    );
  }
  return groups;
}

class _WebGroupCard extends StatelessWidget {
  const _WebGroupCard({required this.group});

  final GroupInfo group;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final capacity = (group.count / 20 * 100).clamp(4, 100).toDouble();
    final attendanceTone = group.avgAtt >= 92
        ? RefPillTone.success
        : group.avgAtt >= 85
        ? RefPillTone.warning
        : RefPillTone.danger;
    return RefPressable(
      onPressed: () => Navigator.of(
        context,
      ).push(sfPageRoute(GroupDetailScreen(group: group, colors: c))),
      borderRadius: RefRadius.lg,
      semanticLabel: group.name,
      child: RefSurfaceCard(
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 10),
        elevated: true,
        child: Column(
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.primarySoft,
                    borderRadius: RefRadius.md,
                  ),
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: Icon(
                      Icons.workspaces_rounded,
                      color: c.primary,
                      size: 19,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RefType.ui(
                          size: 13.5,
                          weight: FontWeight.w800,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${group.teacher} · ${group.branch}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RefType.ui(size: 10, color: c.muted),
                      ),
                    ],
                  ),
                ),
                RefPill(label: '${group.avgAtt}%', tone: attendanceTone),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded, size: 18, color: c.muted),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      minHeight: 5,
                      value: capacity / 100,
                      backgroundColor: c.surface2,
                      valueColor: AlwaysStoppedAnimation(
                        capacity > 90 ? c.warn : c.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Text(
                    '${group.count}/20 · ${group.schedule}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RefType.mono(
                      size: 9,
                      weight: FontWeight.w700,
                      color: c.muted,
                    ),
                  ),
                ),
                if (group.debtors > 0) ...[
                  const SizedBox(width: 7),
                  RefPill(
                    label: tx(
                      context,
                      uz: '${group.debtors} qarz',
                      ru: 'Долг: ${group.debtors}',
                      en: '${group.debtors} debtors',
                    ),
                    tone: RefPillTone.danger,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class WebPaymentsPage extends StatefulWidget {
  const WebPaymentsPage({super.key});

  @override
  State<WebPaymentsPage> createState() => _WebPaymentsPageState();
}

class _WebPaymentsPageState extends State<WebPaymentsPage> {
  final _search = TextEditingController();
  String _query = '';
  int _filter = 0;
  DateTimeRange? _range;

  Future<void> _acceptPayment(AppStore store, SfColors colors) async {
    final entry = await showModalBottomSheet<LedgerEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SfTheme(
        colors: colors,
        child: _PaymentIntakeSheet(
          students: store.students,
          onSave:
              ({
                required student,
                required payer,
                required amount,
                required channel,
                required operationNumber,
                comment,
              }) => store.recordPayment(
                student: student,
                payer: payer,
                amount: amount,
                channel: channel,
                operationNumber: operationNumber,
                comment: comment,
              ),
        ),
      ),
    );
    if (entry == null || !mounted) return;
    setState(() {
      _filter = 1;
      _query = '';
      _search.clear();
    });
    await Navigator.of(
      context,
    ).push(sfPageRoute(LedgerEntryScreen(entry: entry, colors: colors)));
  }

  Future<void> _pickRange() async {
    final value = await showRefDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: _range,
      title: tx(context, uz: 'Davr', ru: 'Период', en: 'Period'),
    );
    if (value != null && mounted) setState(() => _range = value);
  }

  bool _inRange(LedgerEntry entry) {
    if (_range == null) return true;
    final date = _webDate(entry.date);
    if (date == null) return false;
    final end = DateTime(
      _range!.end.year,
      _range!.end.month,
      _range!.end.day,
      23,
      59,
      59,
    );
    return !date.isBefore(_range!.start) && !date.isAfter(end);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final store = AppScope.of(context);
    final entries = store.ledger.where((entry) {
      final q = _query.toLowerCase();
      final filterOk =
          _filter == 0 || (_filter == 1 ? entry.inflow : !entry.inflow);
      return filterOk &&
          _inRange(entry) &&
          (q.isEmpty ||
              '${entry.title} ${entry.who} ${entry.channel}'
                  .toLowerCase()
                  .contains(q));
    }).toList();
    final inflow = entries
        .where((entry) => entry.inflow)
        .fold<num>(0, (sum, entry) => sum + entry.amount);
    final outflow = entries
        .where((entry) => !entry.inflow)
        .fold<num>(0, (sum, entry) => sum + entry.amount);
    return Material(
      color: c.bg,
      child: Column(
        children: [
          RefLargeHeader(
            eyebrow: tx(
              context,
              uz: 'MOLIYA · JORIY OY',
              ru: 'ФИНАНСЫ · ТЕКУЩИЙ МЕСЯЦ',
              en: 'FINANCE · CURRENT MONTH',
            ),
            title: tx(context, uz: 'To‘lovlar', ru: 'Платежи', en: 'Payments'),
            subtitle: tx(
              context,
              uz: 'Tushum, xarajat va qarzdorlik nazorati',
              ru: 'Контроль поступлений, расходов и задолженности',
              en: 'Track income, expenses and outstanding debt',
            ),
            actions: [
              if (store.role == SfRole.manager)
                RefIconAction(
                  icon: Icons.add_card_rounded,
                  tooltip: tx(
                    context,
                    uz: 'To‘lov qabul qilish',
                    ru: 'Принять платёж',
                    en: 'Accept payment',
                  ),
                  onPressed: () => _acceptPayment(store, c),
                ),
              RefIconAction(
                icon: Icons.file_download_outlined,
                tooltip: tr(context, 'btn_report'),
                onPressed: () => Navigator.of(
                  context,
                ).push(sfPageRoute(ReportScreen(colors: c, role: store.role))),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
              children: [
                RefAdaptiveGrid(
                  minCellWidth: 132,
                  children: [
                    RefMetricCard(
                      label: tx(
                        context,
                        uz: 'Tushum',
                        ru: 'Поступления',
                        en: 'Income',
                      ),
                      value: fmtMoneyMln(inflow),
                      icon: Icons.south_west_rounded,
                      tone: RefMetricTone.success,
                      compact: true,
                      uppercaseLabel: false,
                    ),
                    RefMetricCard(
                      label: tx(
                        context,
                        uz: 'Xarajat',
                        ru: 'Расходы',
                        en: 'Expenses',
                      ),
                      value: fmtMoneyMln(outflow),
                      icon: Icons.north_east_rounded,
                      tone: RefMetricTone.danger,
                      compact: true,
                      uppercaseLabel: false,
                    ),
                    RefMetricCard(
                      label: tx(
                        context,
                        uz: 'Balans',
                        ru: 'Баланс',
                        en: 'Balance',
                      ),
                      value: fmtMoneyMln(inflow - outflow),
                      icon: Icons.account_balance_wallet_rounded,
                      tone: RefMetricTone.primary,
                      compact: true,
                      uppercaseLabel: false,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _PaymentChannels(entries: entries),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey('payments-date-range'),
                        onPressed: _pickRange,
                        icon: const Icon(Icons.date_range_rounded),
                        label: Text(
                          _range == null
                              ? tx(
                                  context,
                                  uz: 'Dan — gacha',
                                  ru: 'От — до',
                                  en: 'From — to',
                                )
                              : '${_webShort(_range!.start)} — ${_webShort(_range!.end)}',
                        ),
                      ),
                    ),
                    if (_range != null) ...[
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        key: const ValueKey('payments-reset-range'),
                        tooltip: tx(
                          context,
                          uz: 'Davrni tiklash',
                          ru: 'Сбросить период',
                          en: 'Reset period',
                        ),
                        onPressed: () => setState(() => _range = null),
                        icon: const Icon(Icons.restart_alt_rounded),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                RefSearchField(
                  controller: _search,
                  hint: tx(
                    context,
                    uz: 'To‘lov yoki mijoz qidirish',
                    ru: 'Поиск платежа или клиента',
                    en: 'Search payment or customer',
                  ),
                  onChanged: (value) => setState(() {
                    _query = value;
                  }),
                ),
                const SizedBox(height: 10),
                RefSegmentedControl<int>(
                  values: const [0, 1, 2],
                  selected: _filter,
                  labelOf: (value) => [
                    tr(context, 'f_all'),
                    tx(context, uz: 'Tushum', ru: 'Поступления', en: 'Income'),
                    tx(context, uz: 'Xarajat', ru: 'Расходы', en: 'Expenses'),
                  ][value],
                  onChanged: (value) => setState(() {
                    _filter = value;
                  }),
                ),
                const SizedBox(height: 20),
                RefSectionHeader(
                  title: tx(
                    context,
                    uz: 'Operatsiyalar',
                    ru: 'Операции',
                    en: 'Transactions',
                  ),
                  subtitle: tx(
                    context,
                    uz: '${entries.length} ta yozuv',
                    ru: '${entries.length} записей',
                    en: '${entries.length} records',
                  ),
                ),
                const SizedBox(height: 8),
                if (entries.isEmpty)
                  _WebEmpty(
                    icon: Icons.payments_outlined,
                    text: tx(
                      context,
                      uz: 'Operatsiya topilmadi',
                      ru: 'Операции не найдены',
                      en: 'No transactions found',
                    ),
                  )
                else
                  for (var index = 0; index < entries.length; index++) ...[
                    RefStaggeredReveal(
                      order: index,
                      child: _PaymentEntry(entry: entries[index]),
                    ),
                    const SizedBox(height: 9),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

typedef _SavePayment =
    LedgerEntry Function({
      required Student student,
      required String payer,
      required num amount,
      required String channel,
      required String operationNumber,
      String? comment,
    });

class _PaymentIntakeSheet extends StatefulWidget {
  const _PaymentIntakeSheet({required this.students, required this.onSave});

  final List<Student> students;
  final _SavePayment onSave;

  @override
  State<_PaymentIntakeSheet> createState() => _PaymentIntakeSheetState();
}

class _PaymentIntakeSheetState extends State<_PaymentIntakeSheet> {
  final _form = GlobalKey<FormState>();
  final _payer = TextEditingController();
  final _amount = TextEditingController();
  final _operation = TextEditingController(
    text: 'MAN-${DateTime.now().millisecondsSinceEpoch % 100000000}',
  );
  final _comment = TextEditingController();
  Student? _student;
  String _channel = 'Naqd';

  @override
  void initState() {
    super.initState();
    if (widget.students.isNotEmpty) {
      _selectStudent(widget.students.first);
    }
  }

  void _selectStudent(Student student) {
    _student = student;
    _payer.text = studentProfile(student).fatherName;
  }

  @override
  void dispose() {
    _payer.dispose();
    _amount.dispose();
    _operation.dispose();
    _comment.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_form.currentState?.validate() ?? false) || _student == null) return;
    final normalized = _amount.text.replaceAll(RegExp(r'[^0-9.]'), '');
    final amount = num.parse(normalized);
    final entry = widget.onSave(
      student: _student!,
      payer: _payer.text,
      amount: amount,
      channel: _channel,
      operationNumber: _operation.text,
      comment: _comment.text,
    );
    Navigator.of(context).pop(entry);
  }

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .9,
          ),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Form(
            key: _form,
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.borderStrong,
                      borderRadius: RefRadius.pill,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                RefSectionHeader(
                  title: tx(
                    context,
                    uz: 'To‘lov qabul qilish',
                    ru: 'Принять платёж',
                    en: 'Accept payment',
                  ),
                  subtitle: tx(
                    context,
                    uz: 'Operatsiya kassa daftariga yoziladi va tafsilotlarda ochiladi',
                    ru: 'Операция попадёт в кассовую книгу и откроется в деталях',
                    en: 'The transaction will be saved to the ledger and opened in detail',
                  ),
                ),
                const SizedBox(height: 14),
                if (widget.students.isEmpty)
                  RefStatusTile(
                    icon: Icons.person_search_outlined,
                    title: tx(
                      context,
                      uz: 'O‘quvchilar topilmadi',
                      ru: 'Нет доступных учеников',
                      en: 'No students available',
                    ),
                    subtitle: tx(
                      context,
                      uz: 'Avval o‘quvchi qo‘shing',
                      ru: 'Сначала добавьте ученика',
                      en: 'Add a student first',
                    ),
                    tone: RefMetricTone.warning,
                  )
                else ...[
                  DropdownButtonFormField<Student>(
                    key: const ValueKey('payment-intake-student'),
                    initialValue: _student,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: tr(context, 'unit_student'),
                      prefixIcon: const Icon(Icons.school_outlined),
                    ),
                    items: [
                      for (final student in widget.students)
                        DropdownMenuItem(
                          value: student,
                          child: Text(
                            student.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    selectedItemBuilder: (_) => [
                      for (final student in widget.students)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            student.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (student) {
                      if (student == null) return;
                      setState(() => _selectStudent(student));
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const ValueKey('payment-intake-payer'),
                    controller: _payer,
                    decoration: InputDecoration(
                      labelText: tx(
                        context,
                        uz: 'Kim to‘ladi',
                        ru: 'Кто оплатил',
                        en: 'Paid by',
                      ),
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                    ),
                    validator: (value) => value?.trim().isEmpty == true
                        ? tx(
                            context,
                            uz: 'To‘lovchini kiriting',
                            ru: 'Укажите плательщика',
                            en: 'Enter the payer',
                          )
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const ValueKey('payment-intake-amount'),
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: tx(
                        context,
                        uz: 'Summa',
                        ru: 'Сумма',
                        en: 'Amount',
                      ),
                      prefixIcon: const Icon(Icons.payments_outlined),
                      suffixText: 'UZS',
                    ),
                    validator: (value) {
                      final amount = num.tryParse(
                        (value ?? '').replaceAll(RegExp(r'[^0-9.]'), ''),
                      );
                      return amount == null || amount <= 0
                          ? tx(
                              context,
                              uz: 'Noldan katta summa kiriting',
                              ru: 'Введите сумму больше нуля',
                              en: 'Enter an amount greater than zero',
                            )
                          : null;
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _channel,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: tx(
                        context,
                        uz: 'To‘lov usuli',
                        ru: 'Способ оплаты',
                        en: 'Payment method',
                      ),
                      prefixIcon: const Icon(Icons.credit_card_rounded),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'Naqd',
                        child: Text(
                          tx(context, uz: 'Naqd', ru: 'Наличные', en: 'Cash'),
                        ),
                      ),
                      const DropdownMenuItem(
                        value: 'Click',
                        child: Text('Click'),
                      ),
                      const DropdownMenuItem(
                        value: 'Payme',
                        child: Text('Payme'),
                      ),
                      const DropdownMenuItem(
                        value: 'Uzum',
                        child: Text('Uzum'),
                      ),
                      DropdownMenuItem(
                        value: 'Bank',
                        child: Text(
                          tx(
                            context,
                            uz: 'Bank o‘tkazmasi',
                            ru: 'Банковский перевод',
                            en: 'Bank transfer',
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _channel = value ?? _channel),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _operation,
                    decoration: InputDecoration(
                      labelText: tx(
                        context,
                        uz: 'Operatsiya raqami',
                        ru: 'Номер операции',
                        en: 'Transaction number',
                      ),
                      prefixIcon: const Icon(Icons.tag_rounded),
                    ),
                    validator: (value) => value?.trim().isEmpty == true
                        ? tx(
                            context,
                            uz: 'Operatsiya raqamini kiriting',
                            ru: 'Укажите номер операции',
                            en: 'Enter the transaction number',
                          )
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _comment,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: tx(
                        context,
                        uz: 'Izoh',
                        ru: 'Комментарий',
                        en: 'Comment',
                      ),
                      prefixIcon: const Icon(Icons.comment_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  RefButton(
                    label: tx(
                      context,
                      uz: 'To‘lovni saqlash',
                      ru: 'Сохранить платёж',
                      en: 'Save payment',
                    ),
                    leading: Icons.check_circle_rounded,
                    block: true,
                    onPressed: _save,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentChannels extends StatefulWidget {
  const _PaymentChannels({required this.entries});

  final List<LedgerEntry> entries;

  @override
  State<_PaymentChannels> createState() => _PaymentChannelsState();
}

class _PaymentChannelsState extends State<_PaymentChannels> {
  String? _selected;

  @override
  void didUpdateWidget(covariant _PaymentChannels oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selected != null &&
        !widget.entries.any(
          (entry) => entry.inflow && entry.channel == _selected,
        )) {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final totals = <String, num>{};
    for (final entry in widget.entries.where((entry) => entry.inflow)) {
      final channel = entry.channel.trim().isEmpty
          ? tx(context, uz: 'Boshqa', ru: 'Другое', en: 'Other')
          : entry.channel;
      totals[channel] = (totals[channel] ?? 0) + entry.amount;
    }
    final grandTotal = totals.values.fold<num>(0, (sum, value) => sum + value);
    final channels = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final palette = [
      c.primary,
      c.accent,
      c.success,
      c.warn,
      c.danger,
      const Color(0xFF7B61D1),
    ];
    final selectedIndex = channels.indexWhere(
      (entry) => entry.key == _selected,
    );
    final selected = selectedIndex == -1 ? null : channels[selectedIndex];
    void selectFromPoint(TapDownDetails details) {
      if (channels.isEmpty || grandTotal <= 0) return;
      const center = Offset(49, 49);
      final delta = details.localPosition - center;
      if (delta.distance < 25) {
        setState(() => _selected = null);
        return;
      }
      var angle = math.atan2(delta.dy, delta.dx) + math.pi / 2;
      if (angle < 0) angle += math.pi * 2;
      var cursor = 0.0;
      for (final channel in channels) {
        cursor += channel.value / grandTotal * math.pi * 2;
        if (angle <= cursor) {
          setState(() => _selected = channel.key);
          return;
        }
      }
    }

    return RefSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          GestureDetector(
            key: const ValueKey('payment-channel-donut'),
            onTapDown: selectFromPoint,
            child: SizedBox(
              width: 98,
              height: 98,
              child: CustomPaint(
                painter: _PaymentDonutPainter(
                  values: channels.map((entry) => entry.value).toList(),
                  colors: [
                    for (var index = 0; index < channels.length; index++)
                      palette[index % palette.length],
                  ],
                  background: c.surface2,
                  selectedIndex: selectedIndex,
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(25),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            selected?.key ?? tr(context, 'chart_total'),
                            textAlign: TextAlign.center,
                            style: RefType.ui(
                              size: 9.5,
                              weight: FontWeight.w800,
                              color: c.ink,
                            ),
                          ),
                          Text(
                            selected == null
                                ? fmtMoneyShort(grandTotal)
                                : '${(selected.value / grandTotal * 100).round()}%',
                            style: RefType.mono(
                              size: 10,
                              weight: FontWeight.w800,
                              color: c.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx(
                    context,
                    uz: 'To‘lov usullari',
                    ru: 'Способы оплаты',
                    en: 'Payment methods',
                  ),
                  style: RefType.ui(
                    size: 13.5,
                    weight: FontWeight.w800,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 8),
                if (channels.isEmpty)
                  Text(
                    tx(
                      context,
                      uz: 'Tasdiqlangan tushum yo‘q',
                      ru: 'Нет подтверждённых поступлений',
                      en: 'No confirmed income',
                    ),
                    style: RefType.ui(size: 11, color: c.muted),
                  )
                else
                  for (var index = 0; index < channels.length; index++)
                    InkWell(
                      borderRadius: RefRadius.sm,
                      onTap: () =>
                          setState(() => _selected = channels[index].key),
                      child: _channel(
                        context,
                        palette[index % palette.length],
                        channels[index].key,
                        grandTotal == 0
                            ? '0%'
                            : '${(channels[index].value / grandTotal * 100).round()}%',
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _channel(
    BuildContext context,
    Color color,
    String name,
    String value,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            name,
            style: RefType.ui(size: 11, color: SfTheme.of(context).ink2),
          ),
        ),
        Text(
          value,
          style: RefType.mono(
            size: 11,
            weight: FontWeight.w700,
            color: SfTheme.of(context).ink,
          ),
        ),
      ],
    ),
  );
}

class _PaymentDonutPainter extends CustomPainter {
  const _PaymentDonutPainter({
    required this.values,
    required this.colors,
    required this.background,
    required this.selectedIndex,
  });

  final List<num> values;
  final List<Color> colors;
  final Color background;
  final int selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 7;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final total = values.fold<num>(0, (sum, value) => sum + value);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = background
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13,
    );
    if (total <= 0) return;
    var start = -math.pi / 2;
    for (var index = 0; index < values.length; index++) {
      final sweep = values[index] / total * math.pi * 2;
      canvas.drawArc(
        rect,
        start + .025,
        math.max(0, sweep - .05),
        false,
        Paint()
          ..color = colors[index].withValues(
            alpha: selectedIndex == -1 || selectedIndex == index ? 1 : .3,
          )
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = selectedIndex == index ? 16 : 13,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PaymentDonutPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.colors != colors ||
      oldDelegate.background != background ||
      oldDelegate.selectedIndex != selectedIndex;
}

class _PaymentEntry extends StatelessWidget {
  const _PaymentEntry({required this.entry});
  final LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final tone = entry.inflow ? RefMetricTone.success : RefMetricTone.danger;
    return Semantics(
      key: ValueKey('offline-payment-${entry.id}'),
      button: true,
      label: tx(
        context,
        uz: '${entry.title}. To‘lov tafsilotini ochish',
        ru: '${entry.title}. Открыть детали платежа',
        en: '${entry.title}. Open payment details',
      ),
      child: RefStatusTile(
        icon: entry.inflow
            ? Icons.south_west_rounded
            : Icons.north_east_rounded,
        title: entry.title,
        subtitle: '${entry.who} · ${entry.channel} · ${entry.time}',
        tone: tone,
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${entry.inflow ? '+' : '-'}${fmtMoneyShort(entry.amount)}',
              style: RefType.mono(
                size: 12.5,
                weight: FontWeight.w800,
                color: entry.inflow ? c.success : c.danger,
              ),
            ),
            const SizedBox(height: 4),
            RefPill(
              label: entry.kind,
              tone: entry.inflow ? RefPillTone.success : RefPillTone.danger,
            ),
          ],
        ),
        onTap: () => Navigator.of(
          context,
        ).push(sfPageRoute(LedgerEntryScreen(entry: entry, colors: c))),
      ),
    );
  }
}

class WebMessagesPage extends StatefulWidget {
  const WebMessagesPage({super.key});

  @override
  State<WebMessagesPage> createState() => _WebMessagesPageState();
}

class _WebMessagesPageState extends State<WebMessagesPage> {
  final _search = TextEditingController();
  String _query = '';
  int _folder = 0;
  int _page = 1;
  final int _pageSize = 1000000;
  bool _loadingContacts = false;

  Future<void> _openConversationPicker(AppStore store) async {
    final c = SfTheme.of(context);
    final session = ApiScope.maybeOf(context)?.notifier;
    if (_loadingContacts) return;
    if (session?.authenticated == true) {
      setState(() => _loadingContacts = true);
      try {
        await session!.refresh('threads', force: true);
        if (mounted) syncProductStoreFromApi(session, store);
      } on ApiException catch (error) {
        // Cached threads and contacts remain usable while offline. Only show
        // the refresh failure when there is nothing useful to present.
        if (mounted &&
            store.threads.isEmpty &&
            session!.messagingContacts.isEmpty) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text(error.message),
                behavior: SnackBarBehavior.floating,
              ),
            );
        }
      } finally {
        if (mounted) setState(() => _loadingContacts = false);
      }
    }
    if (!mounted) return;
    final liveContacts = session?.authenticated == true
        ? session!.messagingContacts
        : const <Map<String, dynamic>>[];
    String contactId(Map<String, dynamic> contact) =>
        apiText(apiValue(contact, const ['user_id', 'account_id', 'id', 'pk']));
    String contactName(Map<String, dynamic> contact) => apiText(
      apiValue(contact, const [
        'display_name',
        'full_name',
        'name',
        'username',
      ]),
      fallback: 'Контакт',
    );
    final selfId = '${session?.messagingSelfUserId ?? ''}';
    final threadedParticipants = <String>{};
    for (final thread in store.threads) {
      if (thread.meta.isGroup) continue;
      final participants = thread.meta.participantIds
          .where((id) => id.isNotEmpty && id != selfId)
          .toSet();
      if (participants.length == 1) {
        threadedParticipants.add(participants.single);
      }
    }
    final availableContacts = liveContacts
        .where((contact) {
          final id = contactId(contact);
          return id.isNotEmpty && !threadedParticipants.contains(id);
        })
        .toList(growable: false);
    final target = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SfTheme(
        colors: c,
        child: DraggableScrollableSheet(
          initialChildSize: .68,
          minChildSize: .4,
          maxChildSize: .9,
          expand: false,
          builder: (context, controller) => DecoratedBox(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.border,
                      borderRadius: RefRadius.pill,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                    child: RefSectionHeader(
                      title: 'Начать разговор',
                      subtitle:
                          '${store.threads.length + availableContacts.length} доступных контактов',
                    ),
                  ),
                  Expanded(
                    child: store.threads.isEmpty && availableContacts.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'Backend не вернул доступных контактов',
                                textAlign: TextAlign.center,
                                style: RefType.ui(size: 12, color: c.muted),
                              ),
                            ),
                          )
                        : ListView(
                            controller: controller,
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                            children: [
                              if (store.threads.isNotEmpty) ...[
                                RefSectionHeader(
                                  title: 'Существующие диалоги',
                                  subtitle: '${store.threads.length}',
                                ),
                                const SizedBox(height: 7),
                                for (
                                  var index = 0;
                                  index < store.threads.length;
                                  index++
                                ) ...[
                                  Builder(
                                    builder: (context) {
                                      final thread = store.threads[index].meta;
                                      return RefStatusTile(
                                        icon: thread.isGroup
                                            ? Icons.groups_rounded
                                            : Icons.person_outline_rounded,
                                        title: thread.name,
                                        subtitle: thread.group,
                                        tone: RefMetricTone.neutral,
                                        onTap: () => Navigator.of(
                                          sheetContext,
                                        ).pop(index),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 7),
                                ],
                              ],
                              if (availableContacts.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                RefSectionHeader(
                                  title: 'Новый диалог',
                                  subtitle: '${availableContacts.length}',
                                ),
                                const SizedBox(height: 7),
                                for (final contact in availableContacts) ...[
                                  RefStatusTile(
                                    key: ValueKey(
                                      'messaging-contact-${contactId(contact)}',
                                    ),
                                    icon:
                                        apiText(
                                          apiValue(contact, const [
                                            'principal_kind',
                                            'category',
                                          ]),
                                        ).toLowerCase().contains('teacher')
                                        ? Icons.school_outlined
                                        : Icons.badge_outlined,
                                    title: contactName(contact),
                                    subtitle: apiText(
                                      apiValue(contact, const [
                                        'role_label',
                                        'principal_kind',
                                        'username',
                                      ]),
                                      fallback: 'Сотрудник',
                                    ),
                                    tone: RefMetricTone.primary,
                                    onTap: () =>
                                        Navigator.of(sheetContext).pop(contact),
                                  ),
                                  const SizedBox(height: 7),
                                ],
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (target == null || !mounted) return;
    if (target is int) {
      await Navigator.of(
        context,
      ).push(sfPageRoute(ChatScreen(threadIdx: target, colors: c)));
      return;
    }
    if (target is Map) {
      final contact = Map<String, dynamic>.from(target);
      await openDirectMessagingContact(
        context,
        userId: contactId(contact),
        username: apiText(apiValue(contact, const ['username', 'login'])),
        fullName: contactName(contact),
      );
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final indices = <int>[];
    for (var i = 0; i < store.threads.length; i++) {
      final thread = store.threads[i].meta;
      final archived = store.archived.contains(i);
      final inFolder = switch (_folder) {
        1 => !thread.isGroup && !archived,
        2 => thread.isGroup && !archived,
        3 => thread.unread > 0 && !archived,
        4 => archived,
        _ => !archived,
      };
      if (inFolder &&
          (_query.isEmpty ||
              '${thread.name} ${thread.last}'.toLowerCase().contains(
                _query.toLowerCase(),
              ))) {
        indices.add(i);
      }
    }
    final pageCount = indices.isEmpty
        ? 1
        : ((indices.length + _pageSize - 1) ~/ _pageSize);
    final currentPage = _page.clamp(1, pageCount).toInt();
    final visibleIndices = indices
        .skip((currentPage - 1) * _pageSize)
        .take(_pageSize)
        .toList(growable: false);
    return Column(
      children: [
        RefLargeHeader(
          eyebrow: 'JAMOA ALOQASI',
          title: 'Xabarlar',
          subtitle: 'Muloqotlar va ichki kanallar',
          actions: [
            if (store.role != SfRole.audit)
              RefIconAction(
                key: const ValueKey('messages-new-conversation'),
                icon: _loadingContacts
                    ? Icons.sync_rounded
                    : Icons.edit_outlined,
                tooltip: 'Yangi xabar',
                onPressed: _loadingContacts
                    ? null
                    : () => _openConversationPicker(store),
              ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
            children: [
              RefSearchField(
                controller: _search,
                hint: 'Suhbat qidirish',
                onChanged: (value) => setState(() {
                  _query = value;
                  _page = 1;
                }),
              ),
              const SizedBox(height: 10),
              RefSegmentedControl<int>(
                values: const [0, 1, 2, 3, 4],
                selected: _folder,
                labelOf: (value) => const [
                  'Hammasi',
                  'Shaxsiy',
                  'Guruhlar',
                  'O‘qilmagan',
                  'Arxiv',
                ][value],
                onChanged: (value) => setState(() {
                  _folder = value;
                  _page = 1;
                }),
              ),
              const SizedBox(height: 20),
              RefSectionHeader(
                title: 'Suhbatlar',
                subtitle: '${indices.length} ta suhbat',
              ),
              const SizedBox(height: 8),
              if (indices.isEmpty)
                _WebEmpty(
                  icon: Icons.chat_bubble_outline_rounded,
                  text: 'Suhbat topilmadi',
                )
              else
                for (var order = 0; order < visibleIndices.length; order++) ...[
                  RefStaggeredReveal(
                    order: order,
                    child: _MessageThreadCard(index: visibleIndices[order]),
                  ),
                  const SizedBox(height: 9),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageThreadCard extends StatelessWidget {
  const _MessageThreadCard({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final store = AppScope.of(context);
    final thread = store.threads[index].meta;
    return RefPressable(
      onPressed: () => Navigator.of(
        context,
      ).push(sfPageRoute(ChatScreen(threadIdx: index, colors: c))),
      borderRadius: RefRadius.lg,
      child: RefSurfaceCard(
        padding: const EdgeInsets.all(13),
        elevated: true,
        child: Row(
          children: [
            thread.isGroup
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.primary,
                      borderRadius: RefRadius.md,
                    ),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(Icons.groups_rounded, color: c.surface),
                    ),
                  )
                : SfAvatar(name: thread.name, size: 44),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: RefType.ui(
                            size: 13.5,
                            weight: FontWeight.w800,
                            color: c.ink,
                          ),
                        ),
                      ),
                      Text(
                        thread.time,
                        style: RefType.mono(size: 9.5, color: c.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    thread.group,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RefType.ui(size: 10.5, color: c.muted),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    thread.last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RefType.ui(size: 11.5, color: c.ink2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                if (store.pinned.contains(index))
                  Icon(Icons.push_pin_rounded, size: 14, color: c.muted),
                if (thread.unread > 0) ...[
                  const SizedBox(height: 6),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.primary,
                      borderRadius: RefRadius.pill,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      child: Text(
                        '${thread.unread}',
                        style: RefType.mono(
                          size: 9,
                          weight: FontWeight.w800,
                          color: c.surface,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class WebHrPage extends StatefulWidget {
  const WebHrPage({super.key});

  @override
  State<WebHrPage> createState() => _WebHrPageState();
}

class _WebHrPageState extends State<WebHrPage> {
  final _search = TextEditingController();
  String _query = '';
  int _filter = 0;
  int _page = 1;
  final int _pageSize = 1000000;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final store = AppScope.of(context);
    final staff = store.staff.where((member) {
      final q = _query.toLowerCase();
      final typeOk =
          _filter == 0 ||
          (_filter == 1
              ? member.subject.toLowerCase() != 'operations'
              : member.subject.toLowerCase() == 'operations');
      return typeOk &&
          (q.isEmpty ||
              '${member.fullName} ${member.department} ${member.subject}'
                  .toLowerCase()
                  .contains(q));
    }).toList();
    final pageCount = staff.isEmpty
        ? 1
        : ((staff.length + _pageSize - 1) ~/ _pageSize);
    final currentPage = _page.clamp(1, pageCount).toInt();
    final visibleStaff = staff
        .skip((currentPage - 1) * _pageSize)
        .take(_pageSize)
        .toList(growable: false);
    return Column(
      children: [
        RefLargeHeader(
          eyebrow: '${store.staff.length} XODIM',
          title: 'HR · Xodimlar',
          subtitle: 'Jamoa, ishga qabul va lavozimlar',
          actions: [
            RefIconAction(
              icon: Icons.person_add_alt_1_rounded,
              tooltip: 'Xodim qo‘shish',
              onPressed: () => Navigator.of(
                context,
              ).push(sfPageRoute(StaffCreateScreen(colors: c))),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
            children: [
              RefAdaptiveGrid(
                minCellWidth: 150,
                children: [
                  RefMetricCard(
                    label: 'Jami xodim',
                    value: '${store.staff.length}',
                    icon: Icons.badge_rounded,
                    tone: RefMetricTone.primary,
                  ),
                  RefMetricCard(
                    label: 'O‘qituvchilar',
                    value:
                        '${store.staff.where((s) => s.subject.toLowerCase() != 'operations').length}',
                    icon: Icons.school_rounded,
                    tone: RefMetricTone.success,
                  ),
                  RefMetricCard(
                    label: 'Bo‘limlar',
                    value: '${store.departments.length}',
                    icon: Icons.account_balance_outlined,
                    tone: RefMetricTone.accent,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              RefSearchField(
                controller: _search,
                hint: 'Xodim yoki bo‘lim qidirish',
                onChanged: (value) => setState(() {
                  _query = value;
                  _page = 1;
                }),
              ),
              const SizedBox(height: 10),
              RefSegmentedControl<int>(
                values: const [0, 1, 2],
                selected: _filter,
                labelOf: (value) =>
                    const ['Hammasi', 'O‘qituvchi', 'Ma’muriy'][value],
                onChanged: (value) => setState(() {
                  _filter = value;
                  _page = 1;
                }),
              ),
              const SizedBox(height: 20),
              RefSectionHeader(
                title: 'Jamoa ro‘yxati',
                subtitle: '${staff.length} ta mos natija',
              ),
              const SizedBox(height: 8),
              if (staff.isEmpty)
                _WebEmpty(icon: Icons.badge_outlined, text: 'Xodim topilmadi')
              else
                for (var index = 0; index < visibleStaff.length; index++) ...[
                  RefStaggeredReveal(
                    order: index,
                    child: _StaffCard(member: visibleStaff[index]),
                  ),
                  const SizedBox(height: 9),
                ],
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(top: BorderSide(color: c.border)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
              child: RefButton(
                label: 'Xodim qo‘shish',
                leading: Icons.person_add_alt_1_rounded,
                block: true,
                onPressed: () => Navigator.of(
                  context,
                ).push(sfPageRoute(StaffCreateScreen(colors: c))),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.member});
  final StaffMember member;
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return RefPressable(
      onPressed: () => Navigator.of(
        context,
      ).push(sfPageRoute(StaffDetailScreen(member: member, colors: c))),
      borderRadius: RefRadius.lg,
      child: RefSurfaceCard(
        padding: const EdgeInsets.all(14),
        elevated: true,
        child: Row(
          children: [
            SfAvatar(name: member.fullName, size: 46),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.fullName,
                    style: RefType.ui(
                      size: 14,
                      weight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${member.subject} · ${member.department}',
                    style: RefType.ui(size: 11, color: c.muted),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      RefPill(
                        label: member.salaryType,
                        tone: RefPillTone.success,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        member.branch,
                        style: RefType.mono(size: 10, color: c.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.muted),
          ],
        ),
      ),
    );
  }
}

class WebApprovalsPage extends StatefulWidget {
  const WebApprovalsPage({super.key});
  @override
  State<WebApprovalsPage> createState() => _WebApprovalsPageState();
}

class _WebApprovalsPageState extends State<WebApprovalsPage> {
  int _filter = 0;
  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final approvals = store.approvals
        .where(
          (item) =>
              _filter == 0 ||
              (_filter == 1 ? item.amount > 0 : item.amount == 0),
        )
        .toList();
    return Column(
      children: [
        RefLargeHeader(
          eyebrow: 'BOSHQARUV NAVBATI',
          title: 'Tasdiqlar',
          subtitle: 'So‘rovlarni ko‘rib chiqing va qaror qabul qiling',
          actions: [
            RefIconAction(
              icon: Icons.history_rounded,
              tooltip: 'Tarix',
              onPressed: () => _showInfo(
                context,
                'Tasdiqlar tarixi',
                'Tasdiqlangan pul operatsiyalari Payments ekranida ko‘rinadi.',
              ),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
            children: [
              RefAdaptiveGrid(
                minCellWidth: 150,
                children: [
                  RefMetricCard(
                    label: 'Kutilmoqda',
                    value: '${store.approvals.length}',
                    icon: Icons.pending_actions_rounded,
                    tone: RefMetricTone.warning,
                  ),
                  RefMetricCard(
                    label: 'Moliyaviy',
                    value:
                        '${store.approvals.where((a) => a.amount > 0).length}',
                    icon: Icons.payments_rounded,
                    tone: RefMetricTone.danger,
                  ),
                  RefMetricCard(
                    label: 'Bugun',
                    value:
                        '${store.activities.where((a) => a.kind == 'payment').length}',
                    icon: Icons.task_alt_rounded,
                    tone: RefMetricTone.success,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              RefSegmentedControl<int>(
                values: const [0, 1, 2],
                selected: _filter,
                labelOf: (value) =>
                    const ['Hammasi', 'Moliyaviy', 'Operatsion'][value],
                onChanged: (value) => setState(() => _filter = value),
              ),
              const SizedBox(height: 20),
              RefSectionHeader(
                title: 'So‘rovlar',
                subtitle: '${approvals.length} ta kutilmoqda',
              ),
              const SizedBox(height: 8),
              if (approvals.isEmpty)
                _WebEmpty(
                  icon: Icons.task_alt_rounded,
                  text: 'Kutilayotgan so‘rov yo‘q',
                )
              else
                for (var index = 0; index < approvals.length; index++) ...[
                  RefStaggeredReveal(
                    order: index,
                    child: _ApprovalCard(approval: approvals[index]),
                  ),
                  const SizedBox(height: 9),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({required this.approval});
  final Approval approval;
  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final store = AppScope.of(context);
    return RefSurfaceCard(
      padding: const EdgeInsets.all(14),
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: approval.rail.withValues(alpha: .13),
                  borderRadius: RefRadius.md,
                ),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    approval.amount > 0
                        ? Icons.payments_rounded
                        : Icons.assignment_rounded,
                    color: approval.rail,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      approval.title,
                      style: RefType.ui(
                        size: 13.5,
                        weight: FontWeight.w800,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${approval.who} · ${approval.sub}',
                      style: RefType.ui(size: 11, color: c.muted),
                    ),
                  ],
                ),
              ),
              if (approval.amount > 0)
                Text(
                  fmtMoneyShort(approval.amount),
                  style: RefType.mono(
                    size: 12,
                    weight: FontWeight.w800,
                    color: c.danger,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: RefButton(
                  label: 'Rad etish',
                  kind: RefButtonKind.ghost,
                  leading: Icons.close_rounded,
                  onPressed: () => store.resolve(approval, approved: false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RefButton(
                  label: 'Tasdiqlash',
                  kind: RefButtonKind.primary,
                  leading: Icons.check_rounded,
                  onPressed: () => store.resolve(approval, approved: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WebEmpty extends StatelessWidget {
  const _WebEmpty({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => RefEmptyState(
    icon: icon,
    title: tx(
      context,
      uz: 'Hozircha ma’lumot yo‘q',
      ru: 'Пока нет данных',
      en: 'Nothing here yet',
    ),
    message: text,
  );
}

void _showInfo(BuildContext context, String title, String message) {
  final c = SfTheme.of(context);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: RefSurfaceCard(
          padding: const EdgeInsets.all(18),
          elevated: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: RefType.ui(
                  size: 18,
                  weight: FontWeight.w800,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: RefType.ui(size: 13, color: c.muted, height: 1.4),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: RefButton(
                  label: 'Yopish',
                  kind: RefButtonKind.soft,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
