import 'dart:convert';

import 'package:flutter/material.dart';

import 'data.dart';
import 'i18n.dart';
import 'reference_ui.dart';
import 'settings.dart';
import 'theme.dart';

const Map<String, String> _apiLabels = {
  'id': 'ID',
  'pk': 'ID',
  'uuid': 'Идентификатор',
  'full_name': 'Полное имя',
  'display_name': 'Отображаемое имя',
  'first_name': 'Имя',
  'last_name': 'Фамилия',
  'middle_name': 'Отчество',
  'username': 'Логин',
  'phone': 'Телефон',
  'email': 'Электронная почта',
  'name': 'Название',
  'title': 'Название',
  'description': 'Описание',
  'comment': 'Комментарий',
  'notes': 'Примечания',
  'status': 'Статус',
  'state': 'Состояние',
  'is_active': 'Активен',
  'active': 'Активен',
  'created_at': 'Дата создания',
  'updated_at': 'Последнее изменение',
  'registered_at': 'Дата регистрации',
  'registration_date': 'Дата регистрации',
  'date_joined': 'Дата регистрации',
  'start_date': 'Дата начала',
  'end_date': 'Дата окончания',
  'date': 'Дата',
  'time': 'Время',
  'amount': 'Сумма',
  'paid_amount': 'Оплачено',
  'total': 'Итого',
  'balance': 'Баланс',
  'debt': 'Задолженность',
  'debt_amount': 'Сумма задолженности',
  'outstanding_amount': 'Остаток задолженности',
  'income': 'Доход',
  'expense': 'Расход',
  'salary': 'Зарплата',
  'payment_status': 'Статус платежа',
  'payment_method': 'Способ оплаты',
  'method': 'Способ',
  'operation_number': 'Номер операции',
  'transaction_id': 'Номер операции',
  'student': 'Ученик',
  'student_id': 'ID ученика',
  'student_name': 'Ученик',
  'teacher': 'Преподаватель',
  'teacher_id': 'ID преподавателя',
  'teacher_name': 'Преподаватель',
  'parent': 'Родитель',
  'parent_id': 'ID родителя',
  'group': 'Группа',
  'group_id': 'ID группы',
  'group_name': 'Группа',
  'cohort': 'Группа',
  'cohort_id': 'ID группы',
  'branch': 'Филиал',
  'branch_id': 'ID филиала',
  'branch_name': 'Филиал',
  'department': 'Департамент',
  'department_id': 'ID департамента',
  'department_name': 'Департамент',
  'responsible': 'Ответственный',
  'manager': 'Руководитель',
  'director': 'Руководитель',
  'position': 'Должность',
  'role': 'Роль',
  'role_name': 'Роль',
  'account_type_name': 'Тип аккаунта',
  'attendance': 'Посещаемость',
  'attendance_status': 'Статус посещения',
  'attendance_percent': 'Посещаемость',
  'present': 'Присутствовал',
  'lesson': 'Занятие',
  'lesson_id': 'ID занятия',
  'subject': 'Предмет',
  'score': 'Балл',
  'grade': 'Оценка',
  'progress': 'Прогресс',
  'students': 'Ученики',
  'teachers': 'Преподаватели',
  'payments': 'Платежи',
  'records': 'Записи',
  'results': 'Результаты',
  'items': 'Элементы',
  'data': 'Данные',
  'pagination': 'Страницы',
  'count': 'Количество',
  'page': 'Страница',
  'page_size': 'Записей на странице',
  'has_next': 'Есть следующая страница',
  'has_previous': 'Есть предыдущая страница',
  'action': 'Действие',
  'event': 'Событие',
  'actor': 'Исполнитель',
  'ip_address': 'IP-адрес',
  'user_agent': 'Устройство',
  'request_id': 'Request ID',
};

const Map<String, String> _apiValues = {
  'true': 'Да',
  'false': 'Нет',
  'active': 'Активен',
  'inactive': 'Неактивен',
  'enabled': 'Включено',
  'disabled': 'Выключено',
  'paid': 'Оплачен',
  'unpaid': 'Не оплачен',
  'pending': 'Ожидает',
  'processing': 'Обрабатывается',
  'completed': 'Завершён',
  'approved': 'Подтверждён',
  'rejected': 'Отклонён',
  'cancelled': 'Отменён',
  'canceled': 'Отменён',
  'failed': 'Ошибка',
  'success': 'Успешно',
  'online': 'Онлайн',
  'offline': 'Офлайн',
  'present': 'Присутствовал',
  'absent': 'Отсутствовал',
  'late': 'Опоздал',
  'excused': 'По уважительной причине',
  'male': 'Мужской',
  'female': 'Женский',
  'cash': 'Наличные',
  'card': 'Банковская карта',
  'bank_transfer': 'Банковский перевод',
  'transfer': 'Перевод',
  'click': 'Click',
  'payme': 'Payme',
  'ceo': 'CEO',
  'manager': 'Менеджер',
  'audit': 'Аудитор',
};

const Map<String, String> _apiLabelsUz = {
  'id': 'ID',
  'pk': 'ID',
  'uuid': 'Identifikator',
  'full_name': 'To‘liq ism',
  'display_name': 'Ko‘rinadigan ism',
  'first_name': 'Ism',
  'last_name': 'Familiya',
  'middle_name': 'Otasining ismi',
  'username': 'Login',
  'phone': 'Telefon',
  'email': 'Elektron pochta',
  'name': 'Nomi',
  'title': 'Nomi',
  'description': 'Tavsif',
  'comment': 'Izoh',
  'notes': 'Eslatma',
  'status': 'Holat',
  'state': 'Holat',
  'is_active': 'Faol',
  'active': 'Faol',
  'created_at': 'Yaratilgan sana',
  'updated_at': 'Oxirgi o‘zgarish',
  'registered_at': 'Ro‘yxatdan o‘tgan sana',
  'registration_date': 'Ro‘yxatdan o‘tgan sana',
  'date_joined': 'Ro‘yxatdan o‘tgan sana',
  'start_date': 'Boshlanish sanasi',
  'end_date': 'Tugash sanasi',
  'date': 'Sana',
  'time': 'Vaqt',
  'amount': 'Summa',
  'paid_amount': 'To‘langan',
  'total': 'Jami',
  'balance': 'Balans',
  'debt': 'Qarzdorlik',
  'debt_amount': 'Qarz summasi',
  'outstanding_amount': 'Qolgan qarz',
  'income': 'Daromad',
  'expense': 'Xarajat',
  'salary': 'Ish haqi',
  'payment_status': 'To‘lov holati',
  'payment_method': 'To‘lov usuli',
  'method': 'Usul',
  'operation_number': 'Operatsiya raqami',
  'transaction_id': 'Operatsiya raqami',
  'student': 'O‘quvchi',
  'student_id': 'O‘quvchi ID',
  'student_name': 'O‘quvchi',
  'teacher': 'O‘qituvchi',
  'teacher_id': 'O‘qituvchi ID',
  'teacher_name': 'O‘qituvchi',
  'parent': 'Ota-ona',
  'parent_id': 'Ota-ona ID',
  'group': 'Guruh',
  'group_id': 'Guruh ID',
  'group_name': 'Guruh',
  'cohort': 'Guruh',
  'cohort_id': 'Guruh ID',
  'branch': 'Filial',
  'branch_id': 'Filial ID',
  'branch_name': 'Filial',
  'department': 'Departament',
  'department_id': 'Departament ID',
  'department_name': 'Departament',
  'responsible': 'Mas’ul',
  'manager': 'Rahbar',
  'director': 'Rahbar',
  'position': 'Lavozim',
  'role': 'Rol',
  'role_name': 'Rol',
  'account_type_name': 'Hisob turi',
  'attendance': 'Davomat',
  'attendance_status': 'Davomat holati',
  'attendance_percent': 'Davomat',
  'present': 'Qatnashgan',
  'lesson': 'Dars',
  'lesson_id': 'Dars ID',
  'subject': 'Fan',
  'score': 'Ball',
  'grade': 'Baho',
  'progress': 'Natija',
  'students': 'O‘quvchilar',
  'teachers': 'O‘qituvchilar',
  'payments': 'To‘lovlar',
  'records': 'Yozuvlar',
  'results': 'Natijalar',
  'items': 'Elementlar',
  'data': 'Ma’lumotlar',
  'pagination': 'Sahifalar',
  'count': 'Soni',
  'page': 'Sahifa',
  'page_size': 'Sahifadagi yozuvlar',
  'has_next': 'Keyingi sahifa bor',
  'has_previous': 'Oldingi sahifa bor',
  'action': 'Amal',
  'event': 'Hodisa',
  'actor': 'Bajardi',
  'ip_address': 'IP-manzil',
  'user_agent': 'Qurilma',
  'request_id': 'Request ID',
};

const Map<String, String> _apiValuesUz = {
  'true': 'Ha',
  'false': 'Yo‘q',
  'active': 'Faol',
  'inactive': 'Faol emas',
  'enabled': 'Yoqilgan',
  'disabled': 'O‘chirilgan',
  'paid': 'To‘langan',
  'unpaid': 'To‘lanmagan',
  'pending': 'Kutilmoqda',
  'processing': 'Qayta ishlanmoqda',
  'completed': 'Yakunlangan',
  'approved': 'Tasdiqlangan',
  'rejected': 'Rad etilgan',
  'cancelled': 'Bekor qilingan',
  'canceled': 'Bekor qilingan',
  'failed': 'Xato',
  'success': 'Muvaffaqiyatli',
  'online': 'Onlayn',
  'offline': 'Oflayn',
  'present': 'Qatnashgan',
  'absent': 'Qatnashmagan',
  'late': 'Kechikkan',
  'excused': 'Sababli',
  'male': 'Erkak',
  'female': 'Ayol',
  'cash': 'Naqd pul',
  'card': 'Bank kartasi',
  'bank_transfer': 'Bank o‘tkazmasi',
  'transfer': 'O‘tkazma',
  'click': 'Click',
  'payme': 'Payme',
  'ceo': 'CEO',
  'manager': 'Menejer',
  'audit': 'Auditor',
};

const Map<String, String> _apiValuesEn = {
  'true': 'Yes',
  'false': 'No',
  'active': 'Active',
  'inactive': 'Inactive',
  'enabled': 'Enabled',
  'disabled': 'Disabled',
  'paid': 'Paid',
  'unpaid': 'Unpaid',
  'pending': 'Pending',
  'processing': 'Processing',
  'completed': 'Completed',
  'approved': 'Approved',
  'rejected': 'Rejected',
  'cancelled': 'Cancelled',
  'canceled': 'Cancelled',
  'failed': 'Failed',
  'success': 'Successful',
  'online': 'Online',
  'offline': 'Offline',
  'present': 'Present',
  'absent': 'Absent',
  'late': 'Late',
  'excused': 'Excused',
  'male': 'Male',
  'female': 'Female',
  'cash': 'Cash',
  'card': 'Bank card',
  'bank_transfer': 'Bank transfer',
  'transfer': 'Transfer',
  'click': 'Click',
  'payme': 'Payme',
  'ceo': 'CEO',
  'manager': 'Manager',
  'audit': 'Auditor',
};

String _normalizedKey(Object? rawKey) {
  final source = '${rawKey ?? ''}'.trim();
  return source
      .replaceAllMapped(
        RegExp(r'([a-zа-яё0-9])([A-ZА-ЯЁ])'),
        (match) => '${match.group(1)}_${match.group(2)}',
      )
      .replaceAll('-', '_')
      .replaceAll(' ', '_')
      .toLowerCase();
}

String _titleKey(String normalized) => normalized
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _apiLabel(Object? rawKey, SfLang lang) {
  final source = '${rawKey ?? ''}'.trim();
  if (source.isEmpty) {
    return txLang(lang, uz: 'Qiymat', ru: 'Значение', en: 'Value');
  }
  if (source.contains('.')) {
    return source.split('.').map((part) => _apiLabel(part, lang)).join(' · ');
  }
  final normalized = _normalizedKey(source);
  final known = switch (lang) {
    SfLang.uz => _apiLabelsUz[normalized],
    SfLang.ru => _apiLabels[normalized],
    // Most API identifiers are already English; aliases need only title case.
    SfLang.en => null,
  };
  if (known != null) return known;
  return _titleKey(normalized);
}

String apiHumanLabel(Object? rawKey) => _apiLabel(rawKey, SfLang.ru);

String apiHumanLabelFor(BuildContext context, Object? rawKey) =>
    _apiLabel(rawKey, SettingsScope.maybeOf(context)?.lang ?? SfLang.ru);

bool _looksLikeMoney(String? fieldKey) {
  final key = fieldKey?.toLowerCase() ?? '';
  return const [
    'amount',
    'income',
    'expense',
    'salary',
    'balance',
    'debt',
    'outstanding',
    'price',
    'cost',
    'total_paid',
  ].any(key.contains);
}

bool _looksLikePercent(String? fieldKey) {
  final key = fieldKey?.toLowerCase() ?? '';
  return key.contains('percent') || key.contains('percentage');
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final date =
      '${local.day.toString().padLeft(2, '0')}.'
      '${local.month.toString().padLeft(2, '0')}.${local.year}';
  if (local.hour == 0 && local.minute == 0 && local.second == 0) return date;
  return '$date · ${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String _apiHumanText(Object? value, {String? fieldKey, required SfLang lang}) {
  if (value == null) {
    return txLang(lang, uz: 'Ma’lumot yo‘q', ru: 'Нет данных', en: 'No data');
  }
  if (value is bool) {
    return value
        ? txLang(lang, uz: 'Ha', ru: 'Да', en: 'Yes')
        : txLang(lang, uz: 'Yo‘q', ru: 'Нет', en: 'No');
  }
  if (value is DateTime) return _formatDate(value);
  if (value is num) {
    if (_looksLikeMoney(fieldKey)) return fmtMoney(value);
    if (_looksLikePercent(fieldKey)) return '${value.toString()}%';
    return value.toString();
  }
  if (value is Map) {
    final map = Map<String, dynamic>.from(value);
    final preferred = const [
      'full_name',
      'display_name',
      'name',
      'title',
      'label',
      'username',
      'number',
      'id',
      'pk',
    ];
    for (final key in preferred) {
      final nested = map[key];
      if (nested != null && '$nested'.trim().isNotEmpty) {
        return _apiHumanText(nested, fieldKey: key, lang: lang);
      }
    }
    return txLang(
      lang,
      uz: '${map.length} maydon',
      ru: '${map.length} полей',
      en: '${map.length} fields',
    );
  }
  if (value is Iterable) {
    final items = value.toList(growable: false);
    return items.isEmpty
        ? txLang(lang, uz: 'Yozuvlar yo‘q', ru: 'Нет записей', en: 'No records')
        : txLang(
            lang,
            uz: '${items.length} yozuv',
            ru: '${items.length} записей',
            en: '${items.length} records',
          );
  }
  final text = '$value'.trim();
  if (text.isEmpty) {
    return txLang(lang, uz: 'Ma’lumot yo‘q', ru: 'Нет данных', en: 'No data');
  }
  if (_looksLikeMoney(fieldKey)) {
    final amount = num.tryParse(text.replaceAll(RegExp(r'[\s,]'), ''));
    if (amount != null) return fmtMoney(amount);
  }
  final translated = switch (lang) {
    SfLang.uz => _apiValuesUz[text.toLowerCase()],
    SfLang.ru => _apiValues[text.toLowerCase()],
    SfLang.en => _apiValuesEn[text.toLowerCase()],
  };
  if (translated != null) return translated;
  final isoDate = RegExp(
    r'^\d{4}-\d{2}-\d{2}(?:[T ][0-9:.+-]+Z?)?$',
  ).hasMatch(text);
  if (isoDate) {
    final parsed = DateTime.tryParse(text);
    if (parsed != null) return _formatDate(parsed);
  }
  final key = fieldKey?.toLowerCase() ?? '';
  if (text.contains('_') &&
      (key.contains('status') ||
          key.contains('method') ||
          key.contains('type') ||
          key.contains('role'))) {
    return _titleKey(text.toLowerCase());
  }
  return text;
}

String apiHumanText(Object? value, {String? fieldKey}) =>
    _apiHumanText(value, fieldKey: fieldKey, lang: SfLang.ru);

String apiHumanTextFor(
  BuildContext context,
  Object? value, {
  String? fieldKey,
}) => _apiHumanText(
  value,
  fieldKey: fieldKey,
  lang: SettingsScope.maybeOf(context)?.lang ?? SfLang.ru,
);

/// Converts JSON stored inside a text field back to a structured value for
/// presentation. Some backend JSONField serializers return objects as encoded
/// strings; showing those strings directly would leak JSON into normal UI.
Object? apiPresentationValue(Object? value) {
  if (value is! String) return value;
  final source = value.trim();
  final looksLikeObject = source.startsWith('{') && source.endsWith('}');
  final looksLikeList = source.startsWith('[') && source.endsWith(']');
  if (!looksLikeObject && !looksLikeList) return value;
  try {
    final decoded = jsonDecode(source);
    return decoded is Map || decoded is List ? decoded : value;
  } on FormatException {
    return value;
  }
}

String _recordTitle(BuildContext context, Map<String, dynamic> row, int index) {
  for (final key in const [
    'full_name',
    'display_name',
    'name',
    'title',
    'student_name',
    'teacher_name',
    'group_name',
    'username',
    'number',
    'id',
    'pk',
  ]) {
    final value = row[key];
    if (value != null && '$value'.trim().isNotEmpty) {
      return apiHumanTextFor(context, value, fieldKey: key);
    }
  }
  final lang = SettingsScope.maybeOf(context)?.lang ?? SfLang.ru;
  return txLang(
    lang,
    uz: 'Yozuv ${index + 1}',
    ru: 'Запись ${index + 1}',
    en: 'Record ${index + 1}',
  );
}

class ApiDataCard extends StatelessWidget {
  const ApiDataCard({
    super.key,
    required this.title,
    required this.value,
    this.icon = Icons.list_alt_rounded,
    this.elevated = true,
    this.maxListItems = 20,
  });

  final String title;
  final Object? value;
  final IconData icon;
  final bool elevated;
  final int maxListItems;

  String _countLabel(BuildContext context) {
    final lang = SettingsScope.maybeOf(context)?.lang ?? SfLang.ru;
    final presented = apiPresentationValue(value);
    if (presented is Map) {
      return txLang(
        lang,
        uz: '${presented.length} maydon',
        ru: '${presented.length} полей',
        en: '${presented.length} fields',
      );
    }
    if (presented is Iterable) {
      return txLang(
        lang,
        uz: '${presented.length} yozuv',
        ru: '${presented.length} записей',
        en: '${presented.length} records',
      );
    }
    return txLang(lang, uz: '1 qiymat', ru: '1 значение', en: '1 value');
  }

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return RefSurfaceCard(
      padding: EdgeInsets.zero,
      elevated: elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 11),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: c.primary.withValues(alpha: .1),
                    borderRadius: RefRadius.sm,
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 17, color: c.primary),
                ),
                const SizedBox(width: 10),
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
                  _countLabel(context),
                  style: RefType.mono(size: 9.5, color: c.muted),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 5, 14, 12),
            child: ApiDataValue(value: value, maxListItems: maxListItems),
          ),
        ],
      ),
    );
  }
}

class ApiDataValue extends StatelessWidget {
  const ApiDataValue({
    super.key,
    required this.value,
    this.fieldKey,
    this.depth = 0,
    this.maxListItems = 20,
  });

  final Object? value;
  final String? fieldKey;
  final int depth;
  final int maxListItems;

  @override
  Widget build(BuildContext context) {
    final presented = apiPresentationValue(value);
    if (presented is Map) {
      return _ApiMapValue(
        value: Map<String, dynamic>.from(presented),
        depth: depth,
        maxListItems: maxListItems,
      );
    }
    if (presented is Iterable && presented is! String) {
      return _ApiListValue(
        values: presented.toList(growable: false),
        depth: depth,
        maxListItems: maxListItems,
      );
    }
    final c = SfTheme.of(context);
    return SelectableText(
      apiHumanTextFor(context, presented, fieldKey: fieldKey),
      style: RefType.ui(
        size: 12.5,
        weight: FontWeight.w600,
        color: presented == null ? c.muted : c.ink,
        height: 1.35,
      ),
    );
  }
}

class _ApiMapValue extends StatelessWidget {
  const _ApiMapValue({
    required this.value,
    required this.depth,
    required this.maxListItems,
  });

  final Map<String, dynamic> value;
  final int depth;
  final int maxListItems;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final lang = SettingsScope.maybeOf(context)?.lang ?? SfLang.ru;
    if (value.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          txLang(lang, uz: 'Ma’lumot yo‘q', ru: 'Нет данных', en: 'No data'),
          style: RefType.ui(size: 12, color: c.muted),
        ),
      );
    }
    if (depth >= 8) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          txLang(
            lang,
            uz: '${value.length} ichki maydon',
            ru: '${value.length} вложенных полей',
            en: '${value.length} nested fields',
          ),
          style: RefType.ui(size: 12, color: c.muted),
        ),
      );
    }
    final entries = value.entries.toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < entries.length; index++)
          _ApiField(
            entry: entries[index],
            depth: depth,
            maxListItems: maxListItems,
            showDivider: index < entries.length - 1,
          ),
      ],
    );
  }
}

class _ApiField extends StatelessWidget {
  const _ApiField({
    required this.entry,
    required this.depth,
    required this.maxListItems,
    required this.showDivider,
  });

  final MapEntry<String, dynamic> entry;
  final int depth;
  final int maxListItems;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final normalizedKey = _normalizedKey(entry.key);
    final sensitive =
        const [
          'password',
          'token',
          'secret',
          'authorization',
          'api_key',
          'session_key',
          'access_key',
          'private_key',
        ].any(
          (part) =>
              normalizedKey == part ||
              normalizedKey.startsWith('${part}_') ||
              normalizedKey.endsWith('_$part'),
        );
    final presented = sensitive
        ? '••••••••'
        : apiPresentationValue(entry.value);
    final complex =
        presented is Map || (presented is Iterable && presented is! String);
    return Container(
      padding: EdgeInsets.symmetric(vertical: complex ? 10 : 9),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: c.border))
            : null,
      ),
      child: complex
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  apiHumanLabelFor(context, entry.key),
                  style: RefType.eyebrow(size: 8.5, color: c.muted),
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: c.bg.withValues(alpha: .65),
                    borderRadius: RefRadius.sm,
                    border: Border.all(color: c.border),
                  ),
                  child: ApiDataValue(
                    value: presented,
                    fieldKey: entry.key,
                    depth: depth + 1,
                    maxListItems: maxListItems,
                  ),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 118,
                  child: Text(
                    apiHumanLabelFor(context, entry.key),
                    style: RefType.ui(size: 10.5, color: c.muted, height: 1.3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ApiDataValue(
                    value: presented,
                    fieldKey: entry.key,
                    depth: depth + 1,
                    maxListItems: maxListItems,
                  ),
                ),
              ],
            ),
    );
  }
}

class _ApiListValue extends StatelessWidget {
  const _ApiListValue({
    required this.values,
    required this.depth,
    required this.maxListItems,
  });

  final List<Object?> values;
  final int depth;
  final int maxListItems;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final lang = SettingsScope.maybeOf(context)?.lang ?? SfLang.ru;
    if (values.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Text(
          txLang(
            lang,
            uz: 'Yozuvlar yo‘q',
            ru: 'Нет записей',
            en: 'No records',
          ),
          style: RefType.ui(size: 12, color: c.muted),
        ),
      );
    }
    final visible = values.take(maxListItems).toList(growable: false);
    final allSimple = visible.every(
      (item) => item is! Map && (item is! Iterable || item is String),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < visible.length; index++)
          if (allSimple)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${index + 1}.',
                    style: RefType.mono(size: 10, color: c.muted),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ApiDataValue(
                      value: visible[index],
                      depth: depth + 1,
                      maxListItems: maxListItems,
                    ),
                  ),
                ],
              ),
            )
          else
            _ApiListRecord(
              value: visible[index],
              index: index,
              depth: depth,
              maxListItems: maxListItems,
            ),
        if (values.length > visible.length)
          Padding(
            padding: const EdgeInsets.only(top: 9, bottom: 4),
            child: Text(
              txLang(
                lang,
                uz: '${values.length} yozuvdan ${visible.length} tasi ko‘rsatildi.',
                ru: 'Показано ${visible.length} из ${values.length} записей.',
                en: 'Showing ${visible.length} of ${values.length} records.',
              ),
              style: RefType.ui(size: 10.5, color: c.muted, height: 1.35),
            ),
          ),
      ],
    );
  }
}

class _ApiListRecord extends StatelessWidget {
  const _ApiListRecord({
    required this.value,
    required this.index,
    required this.depth,
    required this.maxListItems,
  });

  final Object? value;
  final int index;
  final int depth;
  final int maxListItems;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final lang = SettingsScope.maybeOf(context)?.lang ?? SfLang.ru;
    final map = value is Map ? Map<String, dynamic>.from(value as Map) : null;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 7),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: RefRadius.sm,
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            map == null
                ? txLang(
                    lang,
                    uz: 'Yozuv ${index + 1}',
                    ru: 'Запись ${index + 1}',
                    en: 'Record ${index + 1}',
                  )
                : _recordTitle(context, map, index),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: RefType.ui(size: 12, weight: FontWeight.w800, color: c.ink),
          ),
          const SizedBox(height: 4),
          ApiDataValue(
            value: value,
            depth: depth + 1,
            maxListItems: maxListItems,
          ),
        ],
      ),
    );
  }
}
