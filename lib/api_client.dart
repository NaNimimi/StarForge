import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'api_catalog.dart';

/// Native builds can be pointed at another server without changing source:
/// `flutter build apk --dart-define=STARFORGE_API_BASE_URL=http://192.168.1.30:8000`.
/// Web keeps using its own origin so the local preview proxy can attach the
/// tenant Host header and avoid browser CORS restrictions.
const String _configuredApiBaseUrl = String.fromEnvironment(
  'STARFORGE_API_BASE_URL',
  defaultValue: 'https://starforge.78.111.91.113.nip.io',
);

String get kDefaultApiBaseUrl =>
    kIsWeb ? Uri.base.origin : _configuredApiBaseUrl;

abstract final class _HttpStatus {
  static const int badRequest = 400;
  static const int paymentRequired = 402;
  static const int unauthorized = 401;
  static const int forbidden = 403;
  static const int notFound = 404;
  static const int tooManyRequests = 429;
  static const int badGateway = 502;
  static const int notImplemented = 501;
}

/// StarForge v1 transport, ported from the web project's `src/api` layer.
///
/// The server returns `{success, data, pagination?}` and authenticates with an
/// opaque Bearer session key. This file deliberately owns transport only: UI
/// code receives plain decoded maps/lists and never needs to know about HTTP,
/// headers, envelope parsing, pagination or request IDs.
class ApiException implements Exception {
  final int status;
  final String message;
  final String? code;
  final Map<String, dynamic>? errors;
  final String requestId;
  final Duration? retryAfter;

  const ApiException({
    required this.status,
    required this.message,
    required this.requestId,
    this.code,
    this.errors,
    this.retryAfter,
  });

  bool get isUnauthorized => status == _HttpStatus.unauthorized;
  bool get isTimeout => status == 0 && message == 'Request timed out';

  @override
  String toString() => 'ApiException($status, $code): $message [$requestId]';
}

class ApiPage {
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic>? pagination;
  const ApiPage({required this.items, this.pagination});

  int get page => _asInt(
    pagination?['page'] ??
        pagination?['current_page'] ??
        pagination?['page_number'],
    1,
  ).clamp(1, 1 << 31);

  int get pageSize => _asInt(
    pagination?['page_size'] ?? pagination?['per_page'] ?? pagination?['limit'],
    items.isEmpty ? 1 : items.length,
  ).clamp(1, 1 << 31);

  int get total => _asInt(
    pagination?['total'] ?? pagination?['count'] ?? pagination?['total_count'],
    items.length,
  ).clamp(0, 1 << 31);

  int get pages {
    final declared = _asInt(
      pagination?['pages'] ??
          pagination?['total_pages'] ??
          pagination?['page_count'],
    );
    if (declared > 0) return declared;
    if (total == 0) return 1;
    return (total / pageSize).ceil().clamp(1, 1 << 31);
  }

  bool get hasNext {
    final declared = pagination?['has_next'];
    if (declared is bool) return declared;
    final next = pagination?['next'] ?? pagination?['next_page'];
    if (next != null && '$next'.trim().isNotEmpty && '$next' != 'false') {
      return true;
    }
    return page < pages;
  }

  bool get hasPrevious {
    final declared = pagination?['has_previous'] ?? pagination?['has_prev'];
    if (declared is bool) return declared;
    final previous =
        pagination?['previous'] ??
        pagination?['prev'] ??
        pagination?['previous_page'];
    if (previous != null &&
        '$previous'.trim().isNotEmpty &&
        '$previous' != 'false') {
      return true;
    }
    return page > 1;
  }
}

int _asInt(Object? value, [int fallback = 0]) =>
    value is int ? value : int.tryParse('$value') ?? fallback;

String _trimUrl(String value) => value.trim().replaceAll(RegExp(r'/+$'), '');

String _requestId() {
  final random = Random.secure();
  final high = random.nextInt(1 << 16).toRadixString(16).padLeft(4, '0');
  final low = random.nextInt(1 << 16).toRadixString(16).padLeft(4, '0');
  return 'sf-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-$high$low';
}

Map<String, dynamic>? _asMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

String? _deepScalar(Object? value, Set<String> keys, [int depth = 0]) {
  if (depth > 8) return null;
  final map = _asMap(value);
  if (map != null) {
    for (final entry in map.entries) {
      if (!keys.contains(entry.key.toLowerCase())) continue;
      final direct = _errorScalarText(entry.value);
      if (direct != null) return direct;
    }
    for (final child in map.values) {
      final nested = _deepScalar(child, keys, depth + 1);
      if (nested != null) return nested;
    }
  } else if (value is Iterable && value is! String) {
    for (final child in value) {
      final nested = _deepScalar(child, keys, depth + 1);
      if (nested != null) return nested;
    }
  }
  return null;
}

String? _errorScalarText(Object? value) {
  if (value is! String && value is! num && value is! bool) return null;
  final text = '$value'.trim();
  return text.isEmpty ? null : text;
}

Map<String, dynamic>? _structuredApiErrors(Map<String, dynamic>? payload) {
  if (payload == null) return null;
  final nestedError = _asMap(payload['error']);
  final result = <String, dynamic>{
    ...?_asMap(payload['errors']),
    ...?_asMap(nestedError?['errors']),
  };
  for (final key in const ['message', 'detail']) {
    final value = payload[key];
    if (value is Map) {
      result.addAll(Map<String, dynamic>.from(value));
    } else if (value is Iterable && value is! String) {
      result.putIfAbsent('detail', () => value.toList(growable: false));
    }
  }
  final nestedDetail = nestedError?['detail'];
  if (nestedDetail is Iterable && nestedDetail is! String) {
    result.putIfAbsent('detail', () => nestedDetail.toList(growable: false));
  }
  return result.isEmpty ? null : result;
}

List<Map<String, dynamic>> _asMapList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

/// Schema-tolerant accessors shared by live detail pages and relation joins.
/// The deployed API has used both snake_case and compact serializers; keeping
/// aliases at this boundary prevents individual screens from inventing their
/// own parsing rules.
Object? apiValue(Map<String, dynamic> row, Iterable<String> keys) {
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

String apiText(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  if (value is String) {
    final source = value.trim();
    final structured =
        (source.startsWith('{') && source.endsWith('}')) ||
        (source.startsWith('[') && source.endsWith(']'));
    if (structured) {
      try {
        final decoded = jsonDecode(source);
        if (decoded is Map || decoded is List) {
          return apiText(decoded, fallback: fallback);
        }
      } on FormatException {
        // Ordinary text that merely contains brackets remains unchanged.
      }
    }
  }
  if (value is Map) {
    final row = Map<String, dynamic>.from(value);
    return apiText(
      apiValue(row, const [
        'full_name',
        'display_name',
        'name',
        'title',
        'label',
        'id',
        'pk',
        'uuid',
      ]),
      fallback: fallback,
    );
  }
  if (value is Iterable) {
    final items = value
        .map((item) => apiText(item))
        .where((item) => item.isNotEmpty);
    return items.isEmpty ? fallback : items.join(', ');
  }
  final text = '$value'.trim();
  return text.isEmpty ? fallback : text;
}

num? apiNumber(Map<String, dynamic> row, Iterable<String> keys) {
  final value = apiValue(row, keys);
  if (value is num) return value;
  return num.tryParse('$value'.replaceAll(RegExp(r'[^0-9.\-]'), ''));
}

/// Whether a payment can be counted as realised income.
///
/// Some serializers omit a status after a payment has settled, so a missing
/// value remains eligible. Explicitly non-final or reversed states must never
/// inflate dashboard and group income.
bool apiPaymentCountsAsSettled(Map<String, dynamic> row) {
  final raw = apiValue(row, const ['payment_status', 'status', 'state']);
  if (raw == null) return true;
  final status = raw.toString().trim().toLowerCase();
  if (status.isEmpty) return true;
  const excluded = {
    'pending',
    'processing',
    'failed',
    'rejected',
    'cancelled',
    'canceled',
    'refunded',
    'reversed',
    'void',
  };
  return !excluded.contains(status);
}

String apiRecordId(Map<String, dynamic> row) => apiText(
  apiValue(row, const [
    'id',
    'pk',
    'uuid',
    'student_id',
    'teacher_id',
    'cohort_id',
    'group_id',
    'parent_id',
    'payment_id',
    'department_id',
  ]),
);

DateTime? apiDate(Object? value) {
  if (value is DateTime) return value;
  if (value is num) {
    final milliseconds = value.abs() < 100000000000
        ? value.toInt() * 1000
        : value.toInt();
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }
  final text = '$value'.trim();
  if (text.isEmpty || text == 'null') return null;
  final direct = DateTime.tryParse(text);
  if (direct != null) return direct;
  final match = RegExp(
    r'^(\d{1,2})[./-](\d{1,2})[./-](\d{4})',
  ).firstMatch(text);
  if (match == null) return null;
  final day = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final year = int.tryParse(match.group(3)!);
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}

/// Inclusive date range for list filters. Query key names stay configurable
/// because the backend contract must decide whether a resource uses
/// `date_from/date_to`, `from/to`, or a different published spelling.
class ApiDateRange {
  final DateTime from;
  final DateTime to;

  ApiDateRange({required DateTime from, required DateTime to})
    : from = from.isBefore(to) ? from : to,
      to = from.isBefore(to) ? to : from;

  Map<String, Object?> toQuery({
    String fromKey = 'date_from',
    String toKey = 'date_to',
  }) => {fromKey: _dateOnly(from), toKey: _dateOnly(to)};

  bool contains(DateTime value) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
    return !value.isBefore(start) && !value.isAfter(end);
  }

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

/// Normalized read model for the required payment detail screen. [raw] is
/// retained so newly added server fields remain inspectable without an app
/// release, while the named getters cover the stable business contract.
class ApiPaymentDetails {
  final Map<String, dynamic> raw;
  const ApiPaymentDetails(this.raw);

  /// Payment serializers in deployed installations range from flat rows to a
  /// compact `{payment: {...}}`/`{transaction: {...}}` shape. Prefer the
  /// top-level business field, then inspect only known payment envelopes. This
  /// keeps the detail screen useful without accidentally borrowing similarly
  /// named fields from unrelated nested entities.
  Object? _value(Iterable<String> keys) {
    final direct = apiValue(raw, keys);
    if (direct != null) return direct;
    for (final container in const [
      'payment',
      'transaction',
      'details',
      'payment_details',
      'metadata',
    ]) {
      final nested = apiValue(raw, [container]);
      if (nested is! Map) continue;
      final value = apiValue(Map<String, dynamic>.from(nested), keys);
      if (value != null) return value;
    }
    return null;
  }

  String get id => apiRecordId(raw);
  num? get amount {
    final value = _value(const [
      'amount',
      'paid_amount',
      'amount_paid',
      'payment_amount',
      'total',
      'sum',
      'value',
    ]);
    if (value is num) return value;
    return num.tryParse('$value'.replaceAll(RegExp(r'[^0-9.\-]'), ''));
  }

  String get method => apiText(
    _value(const [
      'payment_method_name',
      'payment_method',
      'payment_method_display',
      'method_name',
      'method',
      'method_display',
      'channel',
      'provider',
      'provider_name',
      'payment_type',
    ]),
    fallback: '—',
  );
  String get payer => apiText(
    _value(const [
      'payer_name',
      'payer_full_name',
      'payer',
      'paid_by_name',
      'paid_by_full_name',
      'paid_by',
      'parent_name',
      'parent_full_name',
      'parent',
      'customer_name',
      'customer',
      'guardian_name',
      'guardian',
    ]),
    fallback: '—',
  );
  String get student => apiText(
    _value(const [
      'student_name',
      'student_full_name',
      'student',
      'learner_name',
      'learner',
      'child_name',
      'child',
    ]),
    fallback: '—',
  );
  String get group => apiText(
    _value(const [
      'cohort_name',
      'cohort_title',
      'cohort',
      'group_name',
      'group_title',
      'group',
      'class_name',
      'class',
    ]),
    fallback: '—',
  );
  String get teacher => apiText(
    _value(const [
      'teacher_name',
      'teacher_full_name',
      'teacher',
      'instructor_name',
      'instructor_full_name',
      'instructor',
    ]),
    fallback: '—',
  );
  String get branch => apiText(
    _value(const [
      'branch_name',
      'branch_title',
      'branch',
      'location_name',
      'location',
      'office_name',
      'office',
      'campus_name',
      'campus',
    ]),
    fallback: '—',
  );
  String get operationNumber => apiText(
    _value(const [
      'operation_number',
      'operation_id',
      'transaction_number',
      'transaction_id',
      'transaction_code',
      'reference',
      'reference_number',
      'receipt_number',
      'receipt_no',
      'payment_number',
      'external_id',
    ]),
    fallback: id.isEmpty ? '—' : id,
  );
  String get comment => apiText(
    _value(const [
      'comment',
      'comments',
      'note',
      'description',
      'memo',
      'purpose',
      'details',
    ]),
    fallback: '—',
  );
  String get status => apiText(
    _value(const [
      'payment_status_display',
      'payment_status',
      'status_display',
      'status',
      'state',
    ]),
    fallback: '—',
  );
  DateTime? get occurredAt => apiDate(
    _value(const [
      'paid_at',
      'payment_date',
      'processed_at',
      'completed_at',
      'transaction_date',
      'occurred_at',
      'created_at',
      'timestamp',
      'datetime',
      'date',
    ]),
  );

  String get date {
    final explicit = _value(const ['payment_date', 'paid_date', 'date']);
    final parsed = apiDate(explicit);
    if (parsed != null) return ApiDateRange._dateOnly(parsed);
    final text = apiText(explicit);
    if (text.isNotEmpty) return text;
    final occurred = occurredAt;
    return occurred == null ? '—' : ApiDateRange._dateOnly(occurred);
  }

  String get time {
    final explicit = apiText(
      _value(const ['payment_time', 'paid_time', 'transaction_time', 'time']),
    );
    if (explicit.isNotEmpty) return explicit;
    final occurred = occurredAt;
    return occurred == null
        ? '—'
        : '${occurred.hour.toString().padLeft(2, '0')}:'
              '${occurred.minute.toString().padLeft(2, '0')}';
  }
}

/// Cached, client-side group workspace. It joins only resources that already
/// exist in [kApiResources]; missing exam/change/analytics backend contracts
/// remain empty instead of being presented as live data.
class ApiGroupSnapshot {
  final Map<String, dynamic> group;
  final List<Map<String, dynamic>> students;
  final List<Map<String, dynamic>> attendance;
  final List<Map<String, dynamic>> payments;
  final List<Map<String, dynamic>> changes;
  final List<Map<String, dynamic>> exams;
  final Map<String, num> analytics;

  const ApiGroupSnapshot({
    required this.group,
    required this.students,
    required this.attendance,
    required this.payments,
    required this.changes,
    required this.exams,
    required this.analytics,
  });
}

const _identityKeys = <String>[
  'id',
  'pk',
  'uuid',
  'code',
  'number',
  'full_name',
  'display_name',
  'name',
  'title',
  'student_id',
  'teacher_id',
  'cohort_id',
  'group_id',
  'parent_id',
  'department_id',
];

Set<String> _identityTokens(Object? value) {
  final output = <String>{};
  void add(Object? item) {
    if (item == null) return;
    if (item is Map) {
      final row = Map<String, dynamic>.from(item);
      for (final key in _identityKeys) {
        add(apiValue(row, [key]));
      }
      return;
    }
    if (item is Iterable) {
      for (final nested in item) {
        add(nested);
      }
      return;
    }
    final text = '$item'.trim().toLowerCase();
    if (text.isNotEmpty && text != 'null') output.add(text);
  }

  add(value);
  return output;
}

Set<String> _recordIdentity(
  Map<String, dynamic> row, {
  Iterable<String> extraKeys = const [],
}) {
  final output = <String>{};
  for (final key in {..._identityKeys, ...extraKeys}) {
    output.addAll(_identityTokens(apiValue(row, [key])));
  }
  return output;
}

bool _relatedTo(
  Map<String, dynamic> row,
  Set<String> identities,
  Iterable<String> relationKeys,
) {
  if (identities.isEmpty) return false;
  for (final key in relationKeys) {
    final tokens = _identityTokens(apiValue(row, [key]));
    if (tokens.any(identities.contains)) return true;
  }
  return false;
}

DateTime? apiRecordDate(Map<String, dynamic> row) => apiDate(
  apiValue(row, const [
    'paid_at',
    'payment_date',
    'lesson_date',
    'exam_date',
    'issued_at',
    'occurred_at',
    'changed_at',
    'created_at',
    'updated_at',
    'timestamp',
    'date',
  ]),
);

/// Exact instant-level range check used by live reports. Unlike [ApiDateRange],
/// this does not extend [to] to the end of its day, so a future record later
/// today cannot leak into a report generated now.
bool apiRecordWithinInclusivePeriod(
  Map<String, dynamic> row, {
  required DateTime from,
  required DateTime to,
}) {
  final date = apiRecordDate(row);
  if (date == null) return false;
  final start = from.isBefore(to) ? from : to;
  final end = from.isBefore(to) ? to : from;
  return !date.isBefore(start) && !date.isAfter(end);
}

List<Map<String, dynamic>> _deduplicate(Iterable<Map<String, dynamic>> rows) {
  final ids = <String>{};
  final output = <Map<String, dynamic>>[];
  for (final row in rows) {
    final id = apiRecordId(row);
    final key = id.isEmpty ? jsonEncode(row) : id.toLowerCase();
    if (ids.add(key)) output.add(row);
  }
  return output;
}

num _attendancePercent(
  List<Map<String, dynamic>> attendance,
  List<Map<String, dynamic>> students,
) {
  final explicitRates = attendance
      .map(
        (row) => apiNumber(row, const [
          'attendance_percent',
          'attendance_percentage',
          'attendance_rate',
          'rate',
        ]),
      )
      .whereType<num>()
      .toList();
  if (explicitRates.isNotEmpty) {
    return (explicitRates.reduce((a, b) => a + b) / explicitRates.length)
        .round();
  }

  var known = 0;
  var present = 0;
  for (final row in attendance) {
    final value = apiValue(row, const [
      'present',
      'is_present',
      'attended',
      'status',
      'attendance_status',
    ]);
    if (value == null) continue;
    final normalized = '$value'.trim().toLowerCase();
    const positive = {'true', '1', 'present', 'attended', 'late', 'excused'};
    const negative = {'false', '0', 'absent', 'missed', 'no_show'};
    if (!positive.contains(normalized) && !negative.contains(normalized)) {
      continue;
    }
    known++;
    if (positive.contains(normalized)) present++;
  }
  if (known > 0) return (present * 100 / known).round();

  final studentRates = students
      .map(
        (row) => apiNumber(row, const [
          'attendance_percent',
          'attendance_percentage',
          'attendance_rate',
          'attendance',
        ]),
      )
      .whereType<num>()
      .toList();
  if (studentRates.isEmpty) return 0;
  return (studentRates.reduce((a, b) => a + b) / studentRates.length).round();
}

/// Runtime HTTP client. It has no static token or secret; the session is set
/// only after the user signs in from the mobile app.
class StarforgeApiClient {
  String _baseUrl;
  String _language;
  String? _token;
  List<String> _lastWarnings = const [];
  VoidCallback? onUnauthorized;

  StarforgeApiClient({String? baseUrl})
    : _baseUrl = _trimUrl(baseUrl ?? kDefaultApiBaseUrl),
      _language = 'uz';

  String get baseUrl => _baseUrl;
  String? get token => _token;
  bool get hasSession => _token?.isNotEmpty == true;
  List<String> get lastWarnings => _lastWarnings;

  void configure({String? baseUrl, String? language, String? token}) {
    if (baseUrl != null && baseUrl.trim().isNotEmpty) {
      _baseUrl = _trimUrl(baseUrl);
    }
    if (language != null && language.trim().isNotEmpty) {
      _language = language.trim();
    }
    if (token != null) _token = token.trim().isEmpty ? null : token.trim();
  }

  void clearSession() => _token = null;

  Uri _uri(String path, [Map<String, Object?>? query]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final parameters = <String, String>{
      for (final entry in (query ?? const <String, Object?>{}).entries)
        if (entry.value != null && '${entry.value}'.isNotEmpty)
          entry.key: '${entry.value}',
    };
    return Uri.parse(
      '$_baseUrl$cleanPath',
    ).replace(queryParameters: parameters.isEmpty ? null : parameters);
  }

  /// Resolves a center slug using the public platform endpoint. The service has
  /// changed field naming during deployment, so known URL/host spellings are
  /// supported and a clear error is returned for an unknown response shape.
  Future<String> resolveTenant(String slug) async {
    final original = _baseUrl;
    try {
      final data = await request(
        'GET',
        '/api/v1/platform/resolve/',
        query: {'slug': slug.trim()},
        authenticate: false,
      );
      final payload = _asMap(data);
      final direct =
          [
                payload?['api_url'],
                payload?['base_url'],
                payload?['url'],
                payload?['origin'],
              ]
              .whereType<String>()
              .map(_trimUrl)
              .where((item) => item.isNotEmpty)
              .firstOrNull;
      if (direct != null) {
        _baseUrl = direct;
        return direct;
      }
      final host = [payload?['hostname'], payload?['host'], payload?['domain']]
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .firstOrNull;
      if (host == null) {
        throw ApiException(
          status: 0,
          message: 'Tenant resolver did not return an API host.',
          requestId: _requestId(),
        );
      }
      final resolved = host.startsWith('http')
          ? _trimUrl(host)
          : 'https://$host';
      _baseUrl = resolved;
      return resolved;
    } catch (_) {
      _baseUrl = original;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final body = {
      'username': username.trim(),
      'password': password,
      'platform': 'mobile',
    };
    final data = await request(
      'POST',
      '/api/v1/auth/login/',
      body: body,
      authenticate: false,
    );
    final session = _asMap(data) ?? const <String, dynamic>{};
    final access =
        _deepScalar(session, const {
          'access',
          'access_token',
          'token',
          'session_key',
        }) ??
        _errorScalarText(session['session']) ??
        _errorScalarText(session['key']);
    if (access == null || access.isEmpty) {
      throw ApiException(
        status: 0,
        message: 'The server did not return a session key.',
        requestId: _requestId(),
      );
    }
    _token = access;
    return session;
  }

  Future<dynamic> requestPasswordReset(String phone) => request(
    'POST',
    '/api/v1/auth/password/reset/request/',
    body: {'phone': phone.trim()},
    authenticate: false,
  );

  Future<dynamic> confirmPasswordReset({
    required String phone,
    required String code,
    required String newPassword,
  }) => request(
    'POST',
    '/api/v1/auth/password/reset/confirm/',
    body: {
      'phone': phone.trim(),
      'code': code.trim(),
      'new_password': newPassword,
    },
    authenticate: false,
  );

  Future<dynamic> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => request(
    'POST',
    '/api/v1/auth/password/change/',
    body: {'current_password': currentPassword, 'new_password': newPassword},
  );

  Future<void> logout() async {
    try {
      if (hasSession) {
        await request(
          'POST',
          '/api/v1/auth/logout/',
          body: const <String, Object?>{},
        );
      }
    } finally {
      clearSession();
    }
  }

  Future<dynamic> request(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    bool authenticate = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final id = _requestId();
    final client = http.Client();
    try {
      final uri = _uri(path, query);
      final verb = method.toUpperCase();
      final encodedBody = body == null ? null : utf8.encode(jsonEncode(body));
      late final http.BaseRequest request;
      if (kIsWeb) {
        // BrowserClient must not set the forbidden Content-Length header
        // itself. A StreamedRequest leaves it unset, while fetch still sends
        // the buffered Uint8Array with the browser-calculated length.
        final streamed = http.StreamedRequest(verb, uri);
        if (encodedBody != null) streamed.sink.add(encodedBody);
        unawaited(streamed.sink.close());
        request = streamed;
      } else {
        final buffered = http.Request(verb, uri);
        if (encodedBody != null) buffered.bodyBytes = encodedBody;
        request = buffered;
      }
      request.headers['Accept'] = 'application/json';
      request.headers['Accept-Language'] = _language;
      request.headers['X-Request-ID'] = id;
      if (authenticate && hasSession) {
        request.headers['Authorization'] = 'Bearer $_token';
      }
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
      }
      final response = await client.send(request).timeout(timeout);
      final responseBytes = await response.stream.toBytes().timeout(timeout);
      final text = utf8.decode(responseBytes, allowMalformed: false);
      final decoded = text.trim().isEmpty ? null : _decode(text);
      final responseId =
          response.headers['x-request-id'] ??
          _deepScalar(decoded, const {'request_id', 'requestid'}) ??
          id;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (authenticate && response.statusCode == _HttpStatus.unauthorized) {
          clearSession();
          onUnauthorized?.call();
        }
        throw _errorFrom(
          status: response.statusCode,
          payload: decoded,
          requestId: responseId,
          retryAfter: response.headers['retry-after'],
          fallback: response.reasonPhrase,
        );
      }
      return _unwrap(decoded, response.statusCode, responseId);
    } on TimeoutException {
      throw ApiException(
        status: 0,
        message: 'Request timed out',
        requestId: id,
      );
    } on http.ClientException catch (error) {
      throw ApiException(
        status: 0,
        message: 'HTTP transport failed: ${error.message}',
        code: 'transport_error',
        requestId: id,
      );
    } on FormatException {
      throw ApiException(
        status: 0,
        message: 'The server returned an invalid response.',
        code: 'invalid_response',
        requestId: id,
      );
    } on TypeError {
      throw ApiException(
        status: 0,
        message: 'The server returned an unexpected response shape.',
        code: 'invalid_response',
        requestId: id,
      );
    } finally {
      client.close();
    }
  }

  Object? _decode(String value) {
    try {
      return jsonDecode(value);
    } on FormatException {
      return value;
    }
  }

  dynamic _unwrap(Object? value, int status, String requestId) {
    final envelope = _asMap(value);
    if (envelope == null || !envelope.containsKey('success')) {
      _lastWarnings = const [];
      return value;
    }
    if (envelope['success'] != true) {
      throw _errorFrom(status: status, payload: envelope, requestId: requestId);
    }
    final warnings = envelope['warnings'];
    _lastWarnings = warnings is Iterable && warnings is! String
        ? List<String>.unmodifiable(
            warnings
                .map((warning) => '$warning'.trim())
                .where((warning) => warning.isNotEmpty),
          )
        : const [];
    if (envelope.containsKey('pagination')) {
      return <String, dynamic>{
        'data': envelope['data'],
        'pagination': envelope['pagination'],
      };
    }
    return envelope['data'];
  }

  ApiException _errorFrom({
    required int status,
    required Object? payload,
    required String requestId,
    String? retryAfter,
    String? fallback,
  }) {
    final map = _asMap(payload);
    final nestedError = _asMap(map?['error']);
    final seconds = int.tryParse(retryAfter ?? '');
    return ApiException(
      status: status,
      message:
          _errorScalarText(map?['message']) ??
          _errorScalarText(nestedError?['message']) ??
          _errorScalarText(map?['detail']) ??
          _errorScalarText(nestedError?['detail']) ??
          _errorScalarText(map?['error']) ??
          fallback ??
          'Request failed ($status)',
      code:
          _errorScalarText(map?['code']) ??
          _errorScalarText(nestedError?['code']),
      errors: _structuredApiErrors(map),
      requestId: requestId,
      retryAfter: seconds == null ? null : Duration(seconds: seconds),
    );
  }

  /// Fetch a full paginated resource, matching the web store behaviour so
  /// dashboard totals and client-side filters do not stop at the first page.
  Future<ApiPage> list(String path, {Map<String, Object?>? query}) async {
    final requestedPage = _asInt(query?['page'], 1).clamp(1, 1 << 31);
    final requestedSize = _asInt(query?['page_size'], 200).clamp(1, 1000);
    final firstPage = await listPage(
      path,
      query: query,
      page: requestedPage,
      pageSize: requestedSize,
    );
    if (!firstPage.hasNext) {
      return firstPage;
    }

    final items = <Map<String, dynamic>>[...firstPage.items];
    var current = firstPage;
    // A finite guard protects the app from a malformed API that forever
    // advertises `next` while returning the same page.
    for (var requestCount = 0; current.hasNext && requestCount < 1000;) {
      requestCount++;
      final nextPage = current.page + 1;
      final next = await listPage(
        path,
        query: query,
        page: nextPage,
        pageSize: requestedSize,
      );
      items.addAll(next.items);
      if (next.page <= current.page || next.items.isEmpty) break;
      current = next;
    }
    return ApiPage(
      items: items,
      pagination: {
        ...?firstPage.pagination,
        'page': firstPage.page,
        'page_size': requestedSize,
        'total': firstPage.total < items.length
            ? items.length
            : firstPage.total,
        'pages': firstPage.pages,
        'has_next': false,
      },
    );
  }

  /// Fetches exactly one backend page and retains its published metadata.
  ///
  /// Unlike [list], this is suitable for large interactive directories where
  /// the caller owns page controls. It understands both the StarForge
  /// `{data, pagination}` envelope and conventional `{results, count, next}`
  /// responses without inventing totals.
  Future<ApiPage> listPage(
    String path, {
    Map<String, Object?>? query,
    int page = 1,
    int pageSize = 25,
  }) async {
    final safePage = page.clamp(1, 1 << 31);
    final safePageSize = pageSize.clamp(1, 1000);
    final response = await request(
      'GET',
      path,
      query: {...?query, 'page': safePage, 'page_size': safePageSize},
    );
    final map = _asMap(response);
    final items = _asMapList(map?['data'] ?? map?['results'] ?? response);
    final published = _asMap(map?['pagination']);
    final metadata = <String, dynamic>{
      ...?published,
      if (published == null || !published.containsKey('page'))
        'page': map?['page'] ?? map?['current_page'] ?? safePage,
      if (published == null || !published.containsKey('page_size'))
        'page_size':
            map?['page_size'] ??
            map?['per_page'] ??
            map?['limit'] ??
            safePageSize,
      if (published == null || !published.containsKey('total'))
        'total': map?['total'] ?? map?['count'] ?? map?['total_count'],
      if (published == null || !published.containsKey('pages'))
        'pages': map?['pages'] ?? map?['total_pages'] ?? map?['page_count'],
      if (published == null || !published.containsKey('next'))
        'next': map?['next'],
      if (published == null || !published.containsKey('previous'))
        'previous': map?['previous'] ?? map?['prev'],
    }..removeWhere((_, value) => value == null);
    return ApiPage(items: items, pagination: metadata);
  }
}

/// Endpoint registry deliberately mirrors the web project's API resources.
/// Collections lacking a published API operation are not faked as live data.
const Map<String, String> kApiResources = {
  'users': '/api/v1/users/',
  'devices': '/api/v1/users/devices/',
  'students': '/api/v1/students/',
  'teachers': '/api/v1/teachers/',
  'groups': '/api/v1/cohorts/',
  'parents': '/api/v1/parents/',
  'guardians': '/api/v1/parents/guardians/',
  'pickups': '/api/v1/parents/pickups/',
  'enrollmentReasons': '/api/v1/students/enrollment-reasons/',
  'payments': '/api/v1/payments/',
  'attendanceRecords': '/api/v1/attendance/records/',
  'staff': '/api/v1/org/staff/',
  'departments': '/api/v1/org/departments/',
  'branches': '/api/v1/org/branches/',
  'rooms': '/api/v1/org/rooms/',
  'transfers': '/api/v1/org/transfers/',
  'approvals': '/api/v1/approvals/requests/',
  'approvalLedger': '/api/v1/approvals/ledger/',
  'meetings': '/api/v1/meetings/',
  'meetingsUpcoming': '/api/v1/meetings/upcoming/',
  'threads': '/api/v1/messaging/threads/',
  'schedule': '/api/v1/schedule/lessons/',
  'terms': '/api/v1/schedule/terms/',
  'timeslots': '/api/v1/schedule/timeslots/',
  'lessonTypes': '/api/v1/schedule/lesson-types/',
  'scheduleRules': '/api/v1/schedule/rules/',
  'subjects': '/api/v1/academics/subjects/',
  'examTypes': '/api/v1/academics/exam-types/',
  'exams': '/api/v1/academics/exams/',
  'grades': '/api/v1/academics/grades/',
  'transcripts': '/api/v1/academics/transcripts/',
  'assignments': '/api/v1/assignments/',
  'submissions': '/api/v1/assignments/submissions/',
  'contentLibraries': '/api/v1/content/libraries/',
  'contentCourses': '/api/v1/content/courses/',
  'contentModules': '/api/v1/content/modules/',
  'contentLessons': '/api/v1/content/lessons/',
  'contentFolders': '/api/v1/content/folders/',
  'contentFiles': '/api/v1/content/files/',
  'contentMaterials': '/api/v1/content/materials/',
  'printJobs': '/api/v1/printing/jobs/',
  'printers': '/api/v1/printing/printers/',
  'printAgents': '/api/v1/printing/agents/',
  'invoices': '/api/v1/finance/invoices/',
  'expenses': '/api/v1/finance/expenses/',
  'discounts': '/api/v1/finance/discounts/',
  'cashierShifts': '/api/v1/finance/cashier-shifts/',
  'paymentMethods': '/api/v1/finance/payment-methods/',
  'feeSchedules': '/api/v1/finance/fee-schedules/',
  'paymentProviders': '/api/v1/payments/provider-configs/',
  'notificationTemplates': '/api/v1/notifications/templates/',
  'teacherIntelligence': '/api/v1/intelligence/teachers/',
  'studentRisk': '/api/v1/intelligence/risk/',
  'riskRules': '/api/v1/intelligence/rules/',
  'notifications': '/api/v1/notifications/',
  'audit': '/api/v1/audit/',
  'aiRequests': '/api/v1/ai/requests/',
  'reports': '/api/v1/reports/',
  'reportRuns': '/api/v1/reports/runs/',
  'reportSchedules': '/api/v1/reports/schedules/',
  'rules': '/api/v1/rulebook/rules/',
  'rulesMine': '/api/v1/rulebook/rules/mine/',
  'rulesPending': '/api/v1/rulebook/rules/pending/',
  'penalties': '/api/v1/rulebook/penalties/',
  'accessRoles': '/api/v1/access/roles/',
  'accessPermissions': '/api/v1/access/permissions/',
  'accessOverrides': '/api/v1/access/overrides/',
  'forms': '/api/v1/forms/',
  'taskGrades': '/api/v1/tasks/grades/',
  'tasks': '/api/v1/tasks/',
  'tasksMine': '/api/v1/tasks/mine/',
  'achievements': '/api/v1/achievements/',
  'achievementsMine': '/api/v1/achievements/mine/',
  'rewardTypes': '/api/v1/rewards/types/',
  'rewardGrants': '/api/v1/rewards/grants/',
  'rewardGrantsMine': '/api/v1/rewards/grants/mine/',
  'covers': '/api/v1/cover/',
  'coverPool': '/api/v1/cover/pool/',
  'loans': '/api/v1/loans/',
  'procurement': '/api/v1/procurement/',
  'doNotContact': '/api/v1/campaigns/do-not-contact/',
  'campaignTemplates': '/api/v1/campaigns/templates/',
  'campaigns': '/api/v1/campaigns/',
  'sales': '/api/v1/sales/',
  'placementTests': '/api/v1/placement/tests/',
  'placementAttempts': '/api/v1/placement/attempts/',
  'placementProposals': '/api/v1/placement/proposals/',
  'cardTypes': '/api/v1/cards/types/',
  'cards': '/api/v1/cards/',
};

/// A successful login only warms the collections used by the three home
/// dashboards. Every remaining documented collection is loaded lazily by its
/// page. This avoids launching dozens of permission-scoped requests at once
/// while keeping the complete OpenAPI catalogue available through [refresh].
const Set<String> kApiBootstrapResources = {
  'students',
  'teachers',
  'groups',
  'parents',
  'payments',
  'invoices',
  'attendanceRecords',
  'staff',
  'departments',
  'branches',
  'approvals',
  'meetings',
  'threads',
  'schedule',
  'notifications',
  'audit',
};

/// Append-only feeds can grow while they are being read. Loading every audit
/// page during sign-in is therefore both unnecessary and unsafe: each API
/// request can itself create another audit event and keep `has_next` true.
/// Product pages start with the newest backend page and use filters/export for
/// deeper history.
const Set<String> kApiSinglePageResources = {'audit'};

/// Verb capabilities copied from the supplied OpenAPI paths. Generic screens
/// consult these sets before exposing a mutation, so read-only collections can
/// never receive an invented POST/PATCH/DELETE request.
const Set<String> kApiCreatableResources = {
  'devices',
  'staff',
  'branches',
  'departments',
  'rooms',
  'enrollmentReasons',
  'students',
  'guardians',
  'pickups',
  'parents',
  'teachers',
  'groups',
  'terms',
  'timeslots',
  'lessonTypes',
  'scheduleRules',
  'schedule',
  'subjects',
  'examTypes',
  'exams',
  'transcripts',
  'assignments',
  'contentFiles',
  'contentMaterials',
  'printJobs',
  'printers',
  'printAgents',
  'feeSchedules',
  'invoices',
  'discounts',
  'paymentMethods',
  'expenses',
  'cashierShifts',
  'paymentProviders',
  'notificationTemplates',
  'notifications',
  'reportRuns',
  'reportSchedules',
  'approvals',
  'rules',
  'penalties',
  'accessOverrides',
  'forms',
  'taskGrades',
  'tasks',
  'threads',
  'achievements',
  'rewardTypes',
  'rewardGrants',
  'covers',
  'loans',
  'procurement',
  'doNotContact',
  'campaignTemplates',
  'campaigns',
  'sales',
  'meetings',
  'placementTests',
  'placementAttempts',
  'placementProposals',
  'cardTypes',
  'cards',
};

const Set<String> kApiUpdatableResources = {
  'staff',
  'branches',
  'departments',
  'rooms',
  'enrollmentReasons',
  'students',
  'pickups',
  'parents',
  'teachers',
  'groups',
  'terms',
  'timeslots',
  'lessonTypes',
  'scheduleRules',
  'subjects',
  'examTypes',
  'exams',
  'assignments',
  'contentMaterials',
  'printers',
  'feeSchedules',
  'paymentMethods',
  'paymentProviders',
  'notificationTemplates',
  'reportSchedules',
  'rules',
  'accessOverrides',
  'forms',
  'taskGrades',
  'rewardTypes',
  'campaignTemplates',
  'placementTests',
  'cardTypes',
};

const Set<String> kApiDeletableResources = {
  'devices',
  'staff',
  'branches',
  'departments',
  'rooms',
  'enrollmentReasons',
  'students',
  'guardians',
  'pickups',
  'parents',
  'teachers',
  'groups',
  'terms',
  'timeslots',
  'lessonTypes',
  'scheduleRules',
  'subjects',
  'examTypes',
  'exams',
  'assignments',
  'feeSchedules',
  'paymentMethods',
  'paymentProviders',
  'notificationTemplates',
  'rules',
  'accessOverrides',
  'forms',
  'taskGrades',
  'doNotContact',
  'placementTests',
};

const Set<String> kApiDetailResources = {
  'users',
  'students',
  'teachers',
  'groups',
  'parents',
  'guardians',
  'pickups',
  'enrollmentReasons',
  'payments',
  'attendanceRecords',
  'staff',
  'departments',
  'branches',
  'rooms',
  'transfers',
  'approvals',
  'approvalLedger',
  'meetings',
  'threads',
  'schedule',
  'terms',
  'timeslots',
  'lessonTypes',
  'scheduleRules',
  'subjects',
  'examTypes',
  'exams',
  'grades',
  'transcripts',
  'assignments',
  'submissions',
  'contentLibraries',
  'contentCourses',
  'contentModules',
  'contentLessons',
  'contentFolders',
  'contentFiles',
  'contentMaterials',
  'printJobs',
  'printers',
  'printAgents',
  'invoices',
  'expenses',
  'discounts',
  'cashierShifts',
  'paymentMethods',
  'feeSchedules',
  'paymentProviders',
  'notificationTemplates',
  'studentRisk',
  'audit',
  'aiRequests',
  'reports',
  'reportRuns',
  'reportSchedules',
  'rules',
  'penalties',
  'accessOverrides',
  'forms',
  'taskGrades',
  'tasks',
  'achievements',
  'rewardTypes',
  'rewardGrants',
  'covers',
  'loans',
  'procurement',
  'doNotContact',
  'campaignTemplates',
  'campaigns',
  'sales',
  'placementTests',
  'placementAttempts',
  'placementProposals',
  'cardTypes',
  'cards',
};

/// Read-only endpoints whose response is an object/summary rather than a
/// paginated collection. They are kept separate so a dashboard never drops
/// the response while trying to parse it as list rows.
const Map<String, String> kApiDocuments = {
  'studentStats': '/api/v1/students/stats/',
  'studentComparison': '/api/v1/students/comparison/',
  'teacherDashboard': '/api/v1/teachers/dashboard/',
  'attendanceSummary': '/api/v1/attendance/summary/',
  'financeOutstanding': '/api/v1/finance/outstanding/',
  'paymentReconciliation': '/api/v1/payments/reconciliation/',
  'intelligenceBranches': '/api/v1/intelligence/branches/',
  'intelligenceFamilies': '/api/v1/intelligence/families/',
  'aiUsage': '/api/v1/ai/usage-report/',
  'aiBudget': '/api/v1/ai/budget/',
  'unreadNotifications': '/api/v1/notifications/unread-count/',
  'notificationPreferences': '/api/v1/notifications/preferences/',
  'organizationSettings': '/api/v1/org/settings/',
  'systemApps': '/api/v1/org/system/apps/',
  'studentDashboard': '/api/v1/students/me/dashboard/',
  'studentReport': '/api/v1/students/me/report/',
  'studentBirthdays': '/api/v1/students/birthdays/',
  'attendanceExport': '/api/v1/attendance/export/',
  'honorRoll': '/api/v1/academics/honor-roll/',
  'academicWarnings': '/api/v1/academics/warnings/',
  'walletMe': '/api/v1/cards/wallets/me/',
  'parentMyChildren': '/api/v1/parents/me/children/',
  'auditExport': '/api/v1/audit/export/',
  'scheduleIcalUrl': '/api/v1/schedule/ical-url/',
};

const Set<String> kApiBootstrapDocuments = {
  'studentStats',
  'unreadNotifications',
};

/// Minimum read capability for resources that are warmed automatically.
///
/// This is intentionally limited to resources used by bootstrap/dashboard.
/// Purpose-built pages still let the backend be authoritative, while startup
/// no longer probes endpoints a read-only role cannot access.
const Map<String, String> _apiResourceReadPermissions = {
  'students': 'students:read',
  'studentStats': 'students:read',
  'teachers': 'teachers:read',
  'groups': 'cohorts:read',
  'parents': 'parents:read',
  'payments': 'payments:read',
  'invoices': 'finance:read',
  'attendanceRecords': 'attendance:read',
  'staff': 'users:read',
  'departments': 'org:read',
  'branches': 'org:read',
  'approvals': 'approvals:read',
  'meetings': 'meeting:read',
  'threads': 'messaging:read',
  'schedule': 'schedule:read',
  'notifications': 'notifications:read',
  'unreadNotifications': 'notifications:read',
  'studentRisk': 'intelligence:read',
  'audit': 'audit:read',
};

/// App-level authenticated session and live resource cache. It keeps no demo
/// data: after login, each page reads this exact server snapshot and mutations
/// reload only the affected resources.
class ApiSession extends ChangeNotifier {
  static const Duration _resourceFreshness = Duration(seconds: 30);

  final StarforgeApiClient client;
  final Map<String, List<Map<String, dynamic>>> collections = {};
  final Map<String, Map<String, dynamic>> collectionPagination = {};
  final Map<String, ApiException> lastResourceErrors = {};
  final Map<String, dynamic> documents = {};
  final Map<String, DateTime> _loadedAt = {};
  final Map<String, Future<void>> _refreshInFlight = {};
  DateTime? _rateLimitedUntil;
  ApiException? _rateLimitCause;
  Map<String, dynamic>? me;
  bool loading = false;
  String? lastError;

  ApiSession({StarforgeApiClient? client})
    : client = client ?? StarforgeApiClient() {
    this.client.onUnauthorized = _expireSession;
  }

  bool get authenticated => client.hasSession;

  Set<String> get grantedPermissions {
    final profile = me;
    if (profile == null) return const {};
    final collected = <String>{};

    void addValue(Object? value) {
      if (value is String) {
        final permission = value.trim().toLowerCase();
        if (permission.isNotEmpty) collected.add(permission);
        return;
      }
      if (value is Iterable) {
        for (final item in value) {
          addValue(item);
        }
        return;
      }
      final map = _asMap(value);
      if (map == null) return;
      final direct = apiValue(map, const [
        'code',
        'slug',
        'permission',
        'name',
      ]);
      if (direct != null) addValue(direct);
      for (final key in const [
        'permissions',
        'permission_codes',
        'capabilities',
        'grants',
      ]) {
        addValue(map[key]);
      }
    }

    for (final key in const [
      'permissions',
      'permission_codes',
      'capabilities',
      'grants',
      'role',
      'roles',
    ]) {
      final value = profile[key];
      if (key == 'role' && value is String) continue;
      addValue(value);
    }
    return Set.unmodifiable(collected);
  }

  Set<String> get revokedPermissions {
    final profile = me;
    if (profile == null) return const {};
    final collected = <String>{};

    void addValue(Object? value) {
      if (value is String) {
        final permission = value.trim().toLowerCase();
        if (permission.isNotEmpty) collected.add(permission);
      } else if (value is Iterable) {
        for (final item in value) {
          addValue(item);
        }
      }
    }

    addValue(profile['revoked_permissions']);
    addValue(profile['revoked_permission_codes']);
    return Set.unmodifiable(collected);
  }

  bool hasPermission(String permission) {
    final granted = grantedPermissions;
    if (granted.isEmpty) {
      final profile = me;
      final serverPublishedCapabilities =
          profile != null &&
          const [
            'permissions',
            'permission_codes',
            'capabilities',
            'grants',
          ].any(profile.containsKey);
      // Compatibility for older profiles that genuinely omit capabilities.
      // Once the backend publishes an empty list it is authoritative and the
      // UI fails closed instead of probing every endpoint with 403 requests.
      return !serverPublishedCapabilities;
    }
    final wanted = permission.trim().toLowerCase();
    final namespace = wanted.split(':').first;
    final revoked = revokedPermissions;
    if (revoked.contains(wanted) || revoked.contains('$namespace:*')) {
      return false;
    }
    return granted.contains(wanted) ||
        granted.contains('*') ||
        granted.contains('*:*') ||
        granted.contains('$namespace:*');
  }

  bool _mayReadResource(String resource) {
    final permission = _apiResourceReadPermissions[resource];
    return permission == null || hasPermission(permission);
  }

  bool _isFresh(String resource) {
    final loadedAt = _loadedAt[resource];
    return loadedAt != null &&
        DateTime.now().difference(loadedAt) < _resourceFreshness;
  }

  ApiException? _activeRateLimit() {
    final until = _rateLimitedUntil;
    final cause = _rateLimitCause;
    if (until == null || cause == null) return null;
    final remaining = until.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      _rateLimitedUntil = null;
      _rateLimitCause = null;
      return null;
    }
    return ApiException(
      status: _HttpStatus.tooManyRequests,
      code: cause.code ?? 'throttled',
      message: cause.message,
      requestId: cause.requestId,
      errors: cause.errors,
      retryAfter: remaining,
    );
  }

  void _rememberRateLimit(ApiException error) {
    if (error.status != _HttpStatus.tooManyRequests) return;
    final retryAfter = error.retryAfter ?? const Duration(seconds: 60);
    final candidate = DateTime.now().add(retryAfter);
    if (_rateLimitedUntil == null || candidate.isAfter(_rateLimitedUntil!)) {
      _rateLimitedUntil = candidate;
      _rateLimitCause = error;
    }
  }

  void _clearRequestState() {
    _loadedAt.clear();
    _refreshInFlight.clear();
    _rateLimitedUntil = null;
    _rateLimitCause = null;
  }

  void _expireSession() {
    collections.clear();
    collectionPagination.clear();
    lastResourceErrors.clear();
    documents.clear();
    me = null;
    _clearRequestState();
    lastError = 'Session expired. Sign in again.';
    notifyListeners();
  }

  List<Map<String, dynamic>> records(String name) =>
      collections[name] ?? const [];

  /// Raw pagination metadata published by the backend for a collection.
  /// Consumers should prefer [totalFor] for badges and headers.
  Map<String, dynamic>? paginationFor(String resource) =>
      collectionPagination[resource];

  /// Server-authoritative collection total, with the complete cache length as
  /// a fallback for legacy endpoints that do not publish pagination metadata.
  int totalFor(String resource) {
    final pagination = paginationFor(resource);
    return _asInt(
      pagination?['total'] ??
          pagination?['count'] ??
          pagination?['total_count'],
      records(resource).length,
    );
  }

  ApiException? resourceError(String resource) => lastResourceErrors[resource];

  dynamic document(String name) => documents[name];

  Map<String, dynamic>? recordById(String resource, Object? id) {
    final wanted = _identityTokens(id);
    if (wanted.isEmpty) return null;
    for (final record in records(resource)) {
      if (_recordIdentity(record).any(wanted.contains)) return record;
    }
    return null;
  }

  /// Reads a filtered collection without replacing the global cache with a
  /// partial result. This is the safe primitive for date-scoped group history
  /// once the backend publishes the exact supported query parameter names.
  Future<ApiPage> query(
    String resource, {
    Map<String, Object?>? parameters,
  }) async {
    final path = kApiResources[resource];
    if (path == null) {
      throw ArgumentError.value(resource, 'resource', 'Unknown API resource');
    }
    return client.list(path, query: parameters);
  }

  /// Reads one real server page without replacing the complete shared cache.
  /// Search/filter keys are intentionally supplied by the caller because each
  /// endpoint's published contract is authoritative.
  Future<ApiPage> queryPage(
    String resource, {
    Map<String, Object?>? parameters,
    int page = 1,
    int pageSize = 25,
  }) async {
    final path = kApiResources[resource];
    if (path == null) {
      throw ArgumentError.value(resource, 'resource', 'Unknown API resource');
    }
    return client.listPage(
      path,
      query: parameters,
      page: page,
      pageSize: pageSize,
    );
  }

  List<Map<String, dynamic>> relatedRecords(
    String resource, {
    required Object entity,
    required Iterable<String> relationKeys,
    Iterable<String> entityKeys = const [],
    ApiDateRange? range,
  }) {
    final entityMap = entity is Map
        ? Map<String, dynamic>.from(entity)
        : <String, dynamic>{'id': entity};
    final identities = _recordIdentity(entityMap, extraKeys: entityKeys);
    return records(resource)
        .where((row) => _relatedTo(row, identities, relationKeys))
        .where((row) {
          if (range == null) return true;
          final date = apiRecordDate(row);
          return date != null && range.contains(date);
        })
        .toList(growable: false);
  }

  ApiGroupSnapshot groupSnapshot(
    Map<String, dynamic> group, {
    ApiDateRange? range,
  }) {
    const groupIdentityKeys = [
      'cohort_id',
      'group_id',
      'cohort_name',
      'group_name',
    ];
    const groupRelationKeys = [
      'cohort_id',
      'group_id',
      'cohort_name',
      'group_name',
      'cohort',
      'group',
    ];
    final groupIds = _recordIdentity(group, extraKeys: groupIdentityKeys);
    final students = relatedRecords(
      'students',
      entity: group,
      entityKeys: groupIdentityKeys,
      relationKeys: groupRelationKeys,
    );
    final studentIds = <String>{
      for (final student in students)
        ..._recordIdentity(
          student,
          extraKeys: const ['student_id', 'student_name'],
        ),
    };

    bool inRange(Map<String, dynamic> row) {
      if (range == null) return true;
      final date = apiRecordDate(row);
      return date != null && range.contains(date);
    }

    bool belongsToGroupOrStudent(Map<String, dynamic> row) {
      const studentKeys = [
        'student_id',
        'learner_id',
        'student_name',
        'learner_name',
        'student',
        'learner',
      ];
      return _relatedTo(row, groupIds, groupRelationKeys) ||
          _relatedTo(row, studentIds, studentKeys);
    }

    final attendance = records(
      'attendanceRecords',
    ).where(belongsToGroupOrStudent).where(inRange).toList(growable: false);
    final payments = records(
      'payments',
    ).where(belongsToGroupOrStudent).where(inRange).toList(growable: false);
    final changes = relatedRecords(
      'audit',
      entity: group,
      entityKeys: groupIdentityKeys,
      relationKeys: const [
        ...groupRelationKeys,
        'entity_id',
        'object_id',
        'target_id',
        'entity',
        'object',
        'target',
      ],
      range: range,
    );
    // Kept intentionally optional: `exams` is not in kApiResources until the
    // backend publishes an endpoint. Tests/integrations may hydrate this cache
    // key explicitly without the production client claiming it is live.
    final exams = records(
      'exams',
    ).where(belongsToGroupOrStudent).where(inRange).toList(growable: false);

    final settledPayments = payments.where(apiPaymentCountsAsSettled);
    final income = settledPayments.fold<num>(
      0,
      (sum, row) =>
          sum +
          (apiNumber(row, const [
                'amount_uzs',
                'amount',
                'paid_amount',
                'total',
                'value',
              ]) ??
              0),
    );
    final debt = students.fold<num>(
      0,
      (sum, row) =>
          sum +
          (apiNumber(row, const [
                'debt',
                'outstanding',
                'balance_due',
                'amount_due',
              ]) ??
              0),
    );
    final attendancePercent = _attendancePercent(attendance, students);
    return ApiGroupSnapshot(
      group: group,
      students: students,
      attendance: attendance,
      payments: payments,
      changes: changes,
      exams: exams,
      analytics: {
        'student_count': students.length,
        'attendance_percent': attendancePercent,
        'debtor_count': students.where((row) {
          return (apiNumber(row, const [
                    'debt',
                    'outstanding',
                    'balance_due',
                    'amount_due',
                  ]) ??
                  0) >
              0;
        }).length,
        'debt': debt,
        'income': income,
        'payment_count': payments.length,
        'exam_count': exams.length,
      },
    );
  }

  List<Map<String, dynamic>> groupsForTeacher(Map<String, dynamic> teacher) =>
      relatedRecords(
        'groups',
        entity: teacher,
        entityKeys: const ['teacher_id', 'teacher_name'],
        relationKeys: const [
          'teacher_id',
          'instructor_id',
          'teacher_name',
          'instructor_name',
          'teacher',
          'instructor',
        ],
      );

  List<Map<String, dynamic>> studentsForTeacher(Map<String, dynamic> teacher) {
    final groups = groupsForTeacher(teacher);
    return _deduplicate([
      for (final group in groups) ...groupSnapshot(group).students,
      ...relatedRecords(
        'students',
        entity: teacher,
        entityKeys: const ['teacher_id', 'teacher_name'],
        relationKeys: const [
          'teacher_id',
          'instructor_id',
          'teacher_name',
          'instructor_name',
          'teacher',
          'instructor',
        ],
      ),
    ]);
  }

  List<Map<String, dynamic>> childrenForParent(Map<String, dynamic> parent) {
    final embedded = _asMapList(
      apiValue(parent, const ['children', 'students', 'learners']),
    );
    final related = relatedRecords(
      'students',
      entity: parent,
      entityKeys: const [
        'parent_id',
        'parent_name',
        'guardian_id',
        'guardian_name',
      ],
      relationKeys: const [
        'parent_id',
        'guardian_id',
        'parent_name',
        'guardian_name',
        'parent',
        'guardian',
        'parents',
        'guardians',
      ],
    );
    return _deduplicate([...embedded, ...related]);
  }

  List<Map<String, dynamic>> staffForDepartment(
    Map<String, dynamic> department,
  ) => relatedRecords(
    'staff',
    entity: department,
    entityKeys: const ['department_id', 'department_name'],
    relationKeys: const ['department_id', 'department_name', 'department'],
  );

  ApiPaymentDetails? paymentDetails(Object? id) {
    final record = recordById('payments', id);
    return record == null ? null : ApiPaymentDetails(record);
  }

  /// The API has shipped both a raw integer and several object envelopes for
  /// this document. Normalising it here keeps badges and notification chrome
  /// tied to the live source instead of using visual placeholder counts.
  int get unreadNotificationCount {
    final value = document('unreadNotifications');
    if (value is num) return value.toInt();
    final map = _asMap(value);
    return _asInt(
      map?['count'] ?? map?['unread_count'] ?? map?['unread'] ?? map?['total'],
    );
  }

  Future<void> login({
    required String endpoint,
    required String username,
    required String password,
    String language = 'uz',
  }) async {
    loading = true;
    lastError = null;
    notifyListeners();
    try {
      client.configure(baseUrl: endpoint, language: language);
      await client.login(username: username, password: password);
      final profile = await client.request('GET', '/api/v1/users/me/');
      me = _asMap(profile);
      if (me == null) {
        throw ApiException(
          status: _HttpStatus.badGateway,
          message: 'The server returned an invalid account profile.',
          code: 'invalid_profile_response',
          requestId: _requestId(),
        );
      }
      await reloadAll();
    } on ApiException catch (error) {
      _clearLoginState();
      lastError = error.message;
      rethrow;
    } catch (error) {
      _clearLoginState();
      final wrapped = ApiException(
        status: 0,
        message: 'Unexpected login failure (${error.runtimeType}).',
        code: 'login_client_error',
        requestId: _requestId(),
      );
      lastError = wrapped.message;
      throw wrapped;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void _clearLoginState() {
    client.clearSession();
    collections.clear();
    collectionPagination.clear();
    lastResourceErrors.clear();
    documents.clear();
    me = null;
    _clearRequestState();
  }

  Future<void> requestPasswordReset({
    required String endpoint,
    required String phone,
    String language = 'uz',
  }) async {
    client.configure(baseUrl: endpoint, language: language);
    await client.requestPasswordReset(phone);
  }

  Future<void> confirmPasswordReset({
    required String endpoint,
    required String phone,
    required String code,
    required String newPassword,
    String language = 'uz',
  }) async {
    client.configure(baseUrl: endpoint, language: language);
    await client.confirmPasswordReset(
      phone: phone,
      code: code,
      newPassword: newPassword,
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await client.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  Future<String> resolveTenant(String slug) async {
    loading = true;
    lastError = null;
    notifyListeners();
    try {
      return await client.resolveTenant(slug);
    } on ApiException catch (error) {
      lastError = error.message;
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> reloadAll() async {
    final entries = kApiResources.entries
        .where(
          (entry) =>
              kApiBootstrapResources.contains(entry.key) &&
              _mayReadResource(entry.key),
        )
        .toList(growable: false);
    final resourceErrors = <String, ApiException>{};
    final values = await Future.wait(
      entries.map((entry) async {
        try {
          return MapEntry(
            entry.key,
            await _loadCollection(entry.key, entry.value),
          );
        } on ApiException catch (error) {
          _rememberRateLimit(error);
          // `/auth/login` and `/users/me` are the session boundary. Once both
          // succeeded, a role-scoped or temporarily unhealthy optional
          // collection must not throw the user back to the login screen.
          // Preserve the error for the owning page and keep loading the rest.
          if (error.isUnauthorized ||
              error.status == _HttpStatus.paymentRequired) {
            rethrow;
          }
          resourceErrors[entry.key] = error;
          return MapEntry(
            entry.key,
            const ApiPage(items: <Map<String, dynamic>>[]),
          );
        } catch (_) {
          resourceErrors[entry.key] = ApiException(
            status: 0,
            message: 'The server returned invalid ${entry.key} data.',
            code: 'invalid_resource_response',
            requestId: _requestId(),
          );
          return MapEntry(
            entry.key,
            const ApiPage(items: <Map<String, dynamic>>[]),
          );
        }
      }),
    );
    collections
      ..clear()
      ..addEntries(
        values.map((entry) => MapEntry(entry.key, entry.value.items)),
      );
    collectionPagination
      ..clear()
      ..addEntries(
        values
            .where((entry) => entry.value.pagination != null)
            .map((entry) => MapEntry(entry.key, entry.value.pagination!)),
      );
    lastResourceErrors
      ..clear()
      ..addAll(resourceErrors);
    final loadedAt = DateTime.now();
    for (final entry in values) {
      if (!resourceErrors.containsKey(entry.key)) {
        _loadedAt[entry.key] = loadedAt;
      }
    }
    await _reloadDocuments();
    notifyListeners();
  }

  Future<ApiPage> _loadCollection(String name, String path) =>
      kApiSinglePageResources.contains(name)
      ? client.listPage(path, page: 1, pageSize: 200)
      : client.list(path);

  Future<void> _reloadDocuments() async {
    final values = await Future.wait(
      kApiDocuments.entries
          .where(
            (entry) =>
                kApiBootstrapDocuments.contains(entry.key) &&
                _mayReadResource(entry.key),
          )
          .map((entry) async {
            try {
              return MapEntry(
                entry.key,
                await client.request('GET', entry.value),
              );
            } on ApiException catch (error) {
              _rememberRateLimit(error);
              if (error.isUnauthorized ||
                  error.status == _HttpStatus.paymentRequired) {
                rethrow;
              }
              lastResourceErrors[entry.key] = error;
              return MapEntry(entry.key, null);
            } catch (_) {
              lastResourceErrors[entry.key] = ApiException(
                status: 0,
                message: 'The server returned invalid ${entry.key} data.',
                code: 'invalid_resource_response',
                requestId: _requestId(),
              );
              return MapEntry(entry.key, null);
            }
          }),
    );
    documents
      ..clear()
      ..addEntries(values);
    final loadedAt = DateTime.now();
    for (final entry in values) {
      if (!lastResourceErrors.containsKey(entry.key)) {
        _loadedAt[entry.key] = loadedAt;
      }
    }
  }

  Future<void> refresh(String collection, {bool force = false}) {
    final inFlight = _refreshInFlight[collection];
    if (inFlight != null) return inFlight;
    if (!force && _isFresh(collection)) return Future<void>.value();
    final rateLimit = _activeRateLimit();
    if (rateLimit != null) return Future<void>.error(rateLimit);

    final future = _refreshNow(collection);
    _refreshInFlight[collection] = future;
    future.then<void>(
      (_) {
        if (identical(_refreshInFlight[collection], future)) {
          _refreshInFlight.remove(collection);
        }
      },
      onError: (Object _, StackTrace _) {
        if (identical(_refreshInFlight[collection], future)) {
          _refreshInFlight.remove(collection);
        }
      },
    );
    return future;
  }

  Future<void> _refreshNow(String collection) async {
    final path = kApiResources[collection];
    if (path != null) {
      try {
        final page = await _loadCollection(collection, path);
        collections[collection] = page.items;
        if (page.pagination == null) {
          collectionPagination.remove(collection);
        } else {
          collectionPagination[collection] = page.pagination!;
        }
        lastResourceErrors.remove(collection);
        _loadedAt[collection] = DateTime.now();
        notifyListeners();
      } on ApiException catch (error) {
        _rememberRateLimit(error);
        lastResourceErrors[collection] = error;
        notifyListeners();
        rethrow;
      }
      return;
    }
    final documentPath = kApiDocuments[collection];
    if (documentPath == null) return;
    try {
      documents[collection] = await client.request('GET', documentPath);
      lastResourceErrors.remove(collection);
      _loadedAt[collection] = DateTime.now();
      notifyListeners();
    } on ApiException catch (error) {
      _rememberRateLimit(error);
      lastResourceErrors[collection] = error;
      notifyListeners();
      rethrow;
    }
  }

  /// Refreshes the exact resources used by the dashboard.  This is deliberately
  /// narrower than [reloadAll]: opening the home screen should repaint every
  /// live KPI without making unrelated, role-protected requests.
  Future<void> refreshDashboard() async {
    const resources = <String>[
      'payments',
      'invoices',
      'students',
      'staff',
      'teachers',
      'branches',
      'attendanceRecords',
      'studentRisk',
      'audit',
      'unreadNotifications',
    ];
    await Future.wait(
      resources.where(_mayReadResource).map((resource) async {
        try {
          await refresh(resource);
        } on ApiException catch (error) {
          // A role can legitimately be unable to read a dashboard dimension.
          // Keep the rest of the cards fresh and let its dedicated page show the
          // permission state instead of failing the whole dashboard.
          if (error.status != _HttpStatus.forbidden &&
              error.status != _HttpStatus.notFound) {
            rethrow;
          }
        }
      }),
    );
  }

  /// Generic bridge for every documented read endpoint. Screens use the named
  /// resources above for normal data binding; callers with a route containing
  /// an already-known primary key can use this without inventing a DTO.
  Future<dynamic> readPath(
    String path, {
    Map<String, Object?>? query,
    bool paginated = false,
  }) async => paginated
      ? (await client.list(path, query: query)).items
      : client.request('GET', path, query: query);

  /// Executes one operation from the generated OpenAPI catalogue.
  ///
  /// Path templates are resolved only from declared parameters, and the
  /// operation itself must match the immutable generated registry. This gives
  /// the advanced API centre full schema coverage without accepting arbitrary
  /// operator-entered URLs.
  Future<dynamic> executePublishedOperation(
    ApiOperationSpec operation, {
    Map<String, String> pathParameters = const {},
    Map<String, Object?> query = const {},
    Object? body,
  }) async {
    final published = kPublishedApiOperations.any(
      (candidate) =>
          candidate.operationId == operation.operationId &&
          candidate.method == operation.method &&
          candidate.path == operation.path,
    );
    if (!published) {
      throw ArgumentError.value(
        operation.operationId,
        'operation',
        'Operation is not present in the published OpenAPI catalogue',
      );
    }
    var path = operation.path;
    for (final name in operation.pathParameters) {
      final value = pathParameters[name]?.trim() ?? '';
      if (value.isEmpty) {
        throw ArgumentError.value(
          value,
          name,
          'Required API path parameter is empty',
        );
      }
      path = path.replaceAll('{$name}', Uri.encodeComponent(value));
    }
    if (RegExp(r'\{[^}]+\}').hasMatch(path)) {
      throw ArgumentError.value(path, 'path', 'Unresolved path parameter');
    }
    final cleanQuery = <String, Object?>{
      for (final entry in query.entries)
        if (entry.value != null && '${entry.value}'.trim().isNotEmpty)
          entry.key: entry.value,
    };
    if (operation.method == 'GET') {
      return client.request('GET', path, query: cleanQuery);
    }
    return action(
      operation.method,
      path,
      body: operation.acceptsBody ? body : null,
    );
  }

  /// Fetches one detail response for a listed resource. This lets profile
  /// pages display all backend fields even when list serializers are compact.
  Future<Map<String, dynamic>?> detail(String resource, Object? id) async {
    final path = kApiResources[resource];
    final value = id?.toString().trim();
    if (path == null ||
        value == null ||
        value.isEmpty ||
        !kApiDetailResources.contains(resource)) {
      return null;
    }
    final safeId = Uri.encodeComponent(value);
    final data = await client.request('GET', '$path$safeId/');
    return _asMap(data);
  }

  Future<dynamic> action(
    String method,
    String path, {
    Object? body,
    Iterable<String> refreshResources = const [],
  }) async {
    final normalizedMethod = method.toUpperCase();
    final requestBody =
        body ??
        (normalizedMethod == 'POST' ||
                normalizedMethod == 'PUT' ||
                normalizedMethod == 'PATCH'
            ? const <String, Object?>{}
            : null);
    final result = await client.request(
      normalizedMethod,
      path,
      body: requestBody,
    );
    try {
      await Future.wait(
        refreshResources.map((resource) => refresh(resource, force: true)),
      );
    } on ApiException catch (error) {
      // The mutation has already succeeded. A failed follow-up GET must not
      // invite the operator to repeat a payment or approval command.
      lastError =
          'Action completed, but fresh data could not be loaded: '
          '${error.message}';
      notifyListeners();
    }
    return result;
  }

  Future<Map<String, dynamic>?> create(
    String resource,
    Map<String, Object?> body,
  ) async {
    final path = kApiResources[resource];
    if (path == null) {
      throw ArgumentError.value(resource, 'resource', 'Unknown API resource');
    }
    if (!kApiCreatableResources.contains(resource)) {
      throw UnsupportedError('POST is not published for $resource');
    }
    final result = await action(
      'POST',
      path,
      body: body,
      refreshResources: [resource],
    );
    return _asMap(result);
  }

  Future<Map<String, dynamic>?> update(
    String resource,
    Object id,
    Map<String, Object?> body, {
    bool replace = false,
  }) async {
    final path = kApiResources[resource];
    final value = id.toString().trim();
    if (path == null || value.isEmpty) {
      throw ArgumentError.value(resource, 'resource', 'Unknown API resource');
    }
    if (!kApiUpdatableResources.contains(resource)) {
      throw UnsupportedError('PATCH/PUT is not published for $resource');
    }
    final result = await action(
      replace ? 'PUT' : 'PATCH',
      '$path${Uri.encodeComponent(value)}/',
      body: body,
      refreshResources: [resource],
    );
    return _asMap(result);
  }

  Future<void> remove(String resource, Object id) async {
    final path = kApiResources[resource];
    final value = id.toString().trim();
    if (path == null || value.isEmpty) {
      throw ArgumentError.value(resource, 'resource', 'Unknown API resource');
    }
    if (!kApiDeletableResources.contains(resource)) {
      throw UnsupportedError('DELETE is not published for $resource');
    }
    await action(
      'DELETE',
      '$path${Uri.encodeComponent(value)}/',
      refreshResources: [resource],
    );
  }

  Future<dynamic> resourceAction(
    String resource,
    Object id,
    String operation, {
    Object? body,
    Iterable<String> refreshResources = const [],
  }) {
    final path = kApiResources[resource];
    final value = id.toString().trim();
    final actionName = operation.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    if (path == null || value.isEmpty || actionName.isEmpty) {
      throw ArgumentError.value(resource, 'resource', 'Invalid API action');
    }
    return action(
      'POST',
      '$path${Uri.encodeComponent(value)}/$actionName/',
      body: body ?? const <String, Object?>{},
      refreshResources: {resource, ...refreshResources},
    );
  }

  Future<Map<String, dynamic>?> teacherPayoutPolicy(Object teacherId) async {
    final id = Uri.encodeComponent(teacherId.toString().trim());
    if (id.isEmpty) {
      throw ArgumentError.value(teacherId, 'teacherId', 'Missing teacher id');
    }
    final result = await client.request(
      'GET',
      '/api/v1/teachers/$id/payout-policy/',
    );
    return _asMap(result);
  }

  Future<Map<String, dynamic>?> saveTeacherPayoutPolicy(
    Object teacherId,
    Map<String, Object?> body,
  ) async {
    final id = Uri.encodeComponent(teacherId.toString().trim());
    if (id.isEmpty) {
      throw ArgumentError.value(teacherId, 'teacherId', 'Missing teacher id');
    }
    final result = await action(
      'PUT',
      '/api/v1/teachers/$id/payout-policy/',
      body: body,
      refreshResources: const ['teachers'],
    );
    return _asMap(result);
  }

  Future<ApiPage> threadMessages(Object threadId) {
    final id = Uri.encodeComponent(threadId.toString().trim());
    return client.list('/api/v1/messaging/threads/$id/messages/');
  }

  Future<void> sendThreadMessage(Object threadId, String text) async {
    final id = Uri.encodeComponent(threadId.toString().trim());
    await action(
      'POST',
      '/api/v1/messaging/threads/$id/messages/',
      body: {'text': text.trim()},
      refreshResources: const ['threads'],
    );
  }

  /// Sends a prompt only to the published AI endpoint. There is deliberately
  /// no local/canned fallback: callers can distinguish a real server answer
  /// from an unavailable AI service and explain that state honestly.
  Future<String> requestAi(String prompt) async {
    final value = prompt.trim();
    if (!authenticated) {
      throw ApiException(
        status: _HttpStatus.unauthorized,
        message: 'AI backend is not connected.',
        requestId: 'local-ai-unavailable',
      );
    }
    if (value.isEmpty) {
      throw ApiException(
        status: _HttpStatus.badRequest,
        message: 'Enter a prompt.',
        requestId: 'local-ai-empty',
      );
    }
    // The supplied OpenAPI contract publishes AI request history (GET) and
    // exam generation (POST), but no general assistant prompt operation.
    // Never invent a POST to the read-only history collection.
    throw const ApiException(
      status: _HttpStatus.notImplemented,
      code: 'ai_prompt_endpoint_not_published',
      message:
          'AI prompt endpoint is not published by this backend yet. '
          'Request history remains available in AI monitoring.',
      requestId: 'openapi-ai-prompt-missing',
    );
    /*
    if (result is String && result.trim().isNotEmpty) return result.trim();
    final payload = _asMap(result);
    final nested = _asMap(payload?['data']) ?? _asMap(payload?['result']);
    final answer =
        apiValue(payload ?? const {}, const [
          'answer',
          'response',
          'content',
          'message',
          'output',
          'text',
          'result',
        ]) ??
        apiValue(nested ?? const {}, const [
          'answer',
          'response',
          'content',
          'message',
          'output',
          'text',
        ]);
    final text = answer?.toString().trim() ?? '';
    if (text.isEmpty) {
      throw ApiException(
        status: 0,
        message: 'AI endpoint did not return an answer.',
        requestId: 'ai-empty-response',
      );
    }
    return text;
    */
  }

  Future<void> logout() async {
    loading = true;
    notifyListeners();
    try {
      await client.logout();
    } finally {
      // Logging out locally is a privacy boundary, not a best-effort cache
      // refresh. Even if the revoke call fails, credentials and tenant data
      // must leave memory and the UI must leave its loading state.
      client.clearSession();
      collections.clear();
      collectionPagination.clear();
      lastResourceErrors.clear();
      documents.clear();
      me = null;
      _clearRequestState();
      loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    client.onUnauthorized = null;
    super.dispose();
  }
}

/// Access point for the live API session, equivalent to the web StoreContext.
class ApiScope extends InheritedNotifier<ApiSession> {
  const ApiScope({super.key, required ApiSession session, required super.child})
    : super(notifier: session);

  static ApiSession of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope?.notifier != null, 'ApiScope not found in context');
    return scope!.notifier!;
  }

  /// Production startup installs [ApiScope].  A nullable lookup lets the
  /// existing unauthenticated preview shell render without starting a request.
  static ApiScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ApiScope>();
}
