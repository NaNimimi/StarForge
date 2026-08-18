import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show kIsWeb, mapEquals, visibleForTesting;
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_catalog.dart';
import 'session_storage.dart';

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

/// Accepts either a server origin or a mistakenly supplied StarForge API/login
/// URL and reduces it to the server base used by [_uri]. This keeps build-time
/// values such as `https://host/api/v1` from producing
/// `/api/v1/api/v1/...` requests on native builds.
String normalizeStarforgeApiBaseUrl(String value) {
  final raw = _trimUrl(value);
  final parsed = Uri.tryParse(raw);
  if (parsed == null || !parsed.hasScheme || !parsed.hasAuthority) return raw;

  var path = parsed.path.replaceAll(RegExp(r'/+$'), '');
  for (final suffix in const <String>[
    '/api/v1/auth/role-login',
    '/api/v1/auth/login',
    '/api/v1',
    '/api',
  ]) {
    if (path.endsWith(suffix)) {
      path = path.substring(0, path.length - suffix.length);
      break;
    }
  }

  final normalized = Uri(
    scheme: parsed.scheme,
    userInfo: parsed.userInfo,
    host: parsed.host,
    port: parsed.hasPort ? parsed.port : null,
    path: path,
  );
  return _trimUrl(normalized.toString());
}

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
  // Staff responsibilities are published as nested role memberships by the
  // current backend. Treat those memberships as relations as well so branch
  // and department screens do not lose staff whose serializer has no legacy
  // top-level `branch`/`department` fields.
  final memberships = apiValue(row, const [
    'role_memberships',
    'memberships',
    'account_type_assignments',
  ]);
  if (memberships is Iterable && memberships is! String) {
    for (final membership in memberships.whereType<Map>()) {
      final nested = Map<String, dynamic>.from(membership);
      for (final key in relationKeys) {
        final tokens = _identityTokens(apiValue(nested, [key]));
        if (tokens.any(identities.contains)) return true;
      }
    }
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
    : _baseUrl = normalizeStarforgeApiBaseUrl(baseUrl ?? kDefaultApiBaseUrl),
      _language = 'uz';

  String get baseUrl => _baseUrl;
  String? get token => _token;
  bool get hasSession => _token?.isNotEmpty == true;
  List<String> get lastWarnings => _lastWarnings;

  void configure({String? baseUrl, String? language, String? token}) {
    if (baseUrl != null && baseUrl.trim().isNotEmpty) {
      _baseUrl = normalizeStarforgeApiBaseUrl(baseUrl);
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
              .map(normalizeStarforgeApiBaseUrl)
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
          ? normalizeStarforgeApiBaseUrl(host)
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
    final body = {'username': username.trim(), 'password': password};
    const paths = <String>[
      // Role-native CEO, manager, audit, teacher, student and parent accounts
      // authenticate here on the deployed tenant. Trying the platform-admin
      // route first adds a guaranteed failing request to every app login and
      // can consume rate-limit budget.
      '/api/v1/auth/role-login/',
      // Compatibility with older deployments that expose only the published
      // generic login route. Invalid credentials are never retried.
      '/api/v1/auth/login/',
      // Compatibility with proxies configured without APPEND_SLASH.
      '/api/v1/auth/role-login',
      '/api/v1/auth/login',
    ];
    dynamic data;
    for (var index = 0; index < paths.length; index++) {
      try {
        data = await request(
          'POST',
          paths[index],
          body: body,
          authenticate: false,
        );
        break;
      } on ApiException catch (error) {
        final routeIsMissing =
            error.status == _HttpStatus.notFound || error.status == 405;
        if (!routeIsMissing || index == paths.length - 1) rethrow;
      }
    }
    final session = _asMap(data) ?? const <String, dynamic>{};
    final access =
        _errorScalarText(data) ??
        _deepScalar(data, const {
          'access',
          'access_token',
          'token',
          'session_key',
          'key',
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
    body: {'old_password': currentPassword, 'new_password': newPassword},
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

  /// Uploads bytes to the object-storage form returned by the messaging
  /// upload-grant endpoint. The signed form is intentionally sent without the
  /// StarForge bearer token because it targets storage, not the API origin.
  Future<void> uploadMultipartBytes(
    String url,
    Uint8List bytes, {
    required String filename,
    required String contentType,
    required Map<String, String> fields,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw ApiException(
        status: 0,
        code: 'invalid_upload_grant',
        message: 'The server returned an invalid upload URL.',
        requestId: _requestId(),
      );
    }
    final client = http.Client();
    try {
      final request = http.MultipartRequest('POST', uri)
        ..fields.addAll(fields)
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: filename,
            // The storage policy publishes a required `Content-Type` field.
            // Also set the MIME type on the file part: several Android HTTP
            // stacks otherwise send recorded M4A data as octet-stream, and
            // object storage can reject or misclassify the voice upload.
            contentType: MediaType.parse(contentType),
          ),
        );
      final response = await client.send(request).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.stream.drain<void>();
        throw ApiException(
          status: response.statusCode,
          code: 'attachment_upload_failed',
          message: 'Attachment upload failed.',
          requestId: _requestId(),
        );
      }
      await response.stream.drain<void>();
    } on TimeoutException {
      throw ApiException(
        status: 0,
        code: 'attachment_upload_timeout',
        message: 'Attachment upload timed out.',
        requestId: _requestId(),
      );
    } on http.ClientException catch (error) {
      throw ApiException(
        status: 0,
        code: 'attachment_upload_transport_error',
        message: 'Attachment upload failed: ${error.message}',
        requestId: _requestId(),
      );
    } finally {
      client.close();
    }
  }

  /// Uploads a file to a presigned PUT grant. Object storage, not StarForge,
  /// is the destination, therefore no API bearer token is attached.
  Future<void> uploadPutBytes(
    String url,
    Uint8List bytes, {
    required String contentType,
    Map<String, String> headers = const {},
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw ApiException(
        status: 0,
        code: 'invalid_upload_grant',
        message: 'The server returned an invalid upload URL.',
        requestId: _requestId(),
      );
    }
    final client = http.Client();
    try {
      final response = await client
          .put(
            uri,
            headers: <String, String>{
              ...headers,
              if (!headers.keys.any(
                (key) => key.toLowerCase() == 'content-type',
              ))
                'Content-Type': contentType,
            },
            body: bytes,
          )
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          status: response.statusCode,
          code: 'attachment_upload_failed',
          message: 'Attachment upload failed.',
          requestId: _requestId(),
        );
      }
    } on TimeoutException {
      throw ApiException(
        status: 0,
        code: 'attachment_upload_timeout',
        message: 'Attachment upload timed out.',
        requestId: _requestId(),
      );
    } on http.ClientException catch (error) {
      throw ApiException(
        status: 0,
        code: 'attachment_upload_transport_error',
        message: 'Attachment upload failed: ${error.message}',
        requestId: _requestId(),
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
    // The deployed StarForge listing contract caps every ordinary collection
    // at 100 rows. Sending the previous default of 200 is rejected by older
    // deployments as `Invalid value for filter 'page_size'` instead of being
    // silently capped. Keep the transport inside the strictest published
    // contract and follow `has_next` until the full collection is loaded.
    final requestedSize = _asInt(query?['page_size'], 100).clamp(1, 100);
    final firstPage = await listPage(
      path,
      query: query,
      page: requestedPage,
      pageSize: requestedSize,
    );
    // A collection cache is a set of backend records, not a transcript of
    // pages.  Some deployments have returned overlapping pages while rows
    // were being inserted, and a few older proxies ignored `page` entirely.
    // Canonicalise even a one-page response so the product never renders the
    // same database row more than once.
    final items = _deduplicate(firstPage.items);
    if (!firstPage.hasNext) {
      if (firstPage.total > firstPage.items.length) {
        throw ApiException(
          status: _HttpStatus.badGateway,
          code: 'invalid_pagination',
          message:
              'The server ended pagination before all records were returned.',
          requestId: _requestId(),
        );
      }
      return ApiPage(
        items: items,
        pagination: {
          ...?firstPage.pagination,
          'page': firstPage.page,
          'page_size': requestedSize,
          'total': items.length,
          'pages': 1,
          'has_next': false,
          'complete': true,
        },
      );
    }

    final itemKeys = <String>{
      for (final row in items)
        apiRecordId(row).isEmpty
            ? jsonEncode(row)
            : apiRecordId(row).toLowerCase(),
    };
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
      var added = 0;
      for (final row in next.items) {
        final id = apiRecordId(row);
        final key = id.isEmpty ? jsonEncode(row) : id.toLowerCase();
        if (itemKeys.add(key)) {
          items.add(row);
          added++;
        }
      }
      // Do not keep downloading a malformed/repeated first page. This is the
      // source of the former multiplied student directory and slow sign-in.
      if (next.page <= current.page || next.items.isEmpty || added == 0) break;
      current = next;
      if (firstPage.total > 0 && items.length >= firstPage.total) break;
    }
    if (current.hasNext &&
        (firstPage.total <= 0 || items.length < firstPage.total)) {
      throw ApiException(
        status: _HttpStatus.badGateway,
        code: 'invalid_pagination',
        message:
            'The server repeated or stopped pagination before all records were returned.',
        requestId: _requestId(),
      );
    }
    return ApiPage(
      items: items,
      pagination: {
        ...?firstPage.pagination,
        'page': firstPage.page,
        'page_size': requestedSize,
        // [list] is the fully materialised, canonical cache. Publishing the
        // server's pre-deduplication total here would make dashboard counters
        // disagree with the actual rows shown in the student directory.
        'total': items.length,
        'pages': 1,
        'has_next': false,
        'complete': true,
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
    final safePageSize = pageSize.clamp(1, 100);
    final response = await request(
      'GET',
      path,
      query: {...?query, 'page': safePage, 'page_size': safePageSize},
    );
    final map = _asMap(response);
    final items = _asMapList(map?['data'] ?? map?['results'] ?? response);
    final published = _asMap(map?['pagination']);
    final declaredTotal = _asInt(
      published?['total'] ??
          published?['count'] ??
          published?['total_count'] ??
          map?['total'] ??
          map?['count'] ??
          map?['total_count'],
    );
    final hasPublishedPageSize =
        published?.containsKey('page_size') == true ||
        published?.containsKey('per_page') == true ||
        published?.containsKey('limit') == true ||
        map?.containsKey('page_size') == true ||
        map?.containsKey('per_page') == true ||
        map?.containsKey('limit') == true;
    // A few StarForge deployments cap a page internally but omit
    // `page_size` from the response. Treating the requested 100 as the actual
    // size then makes `total=40, data.length=2` look like a one-page result.
    // Infer the effective size from the returned page whenever the server
    // publishes a larger total, so [list] continues until every row is read.
    final effectivePageSize =
        !hasPublishedPageSize &&
            items.isNotEmpty &&
            declaredTotal > items.length
        ? items.length
        : safePageSize;
    final metadata = <String, dynamic>{
      ...?published,
      if (published == null || !published.containsKey('page'))
        'page': map?['page'] ?? map?['current_page'] ?? safePage,
      if (published == null || !published.containsKey('page_size'))
        'page_size':
            map?['page_size'] ??
            map?['per_page'] ??
            map?['limit'] ??
            effectivePageSize,
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

  /// Fetches one cursor-based collection page. Cursor endpoints reject the
  /// ordinary `page` parameter, so they must never pass through [listPage].
  Future<ApiPage> cursorPage(
    String path, {
    Map<String, Object?>? query,
    int pageSize = 50,
  }) async {
    final safePageSize = pageSize.clamp(1, 100);
    final response = await request(
      'GET',
      path,
      query: {...?query, 'page_size': safePageSize},
    );
    final map = _asMap(response);
    final items = _asMapList(map?['results'] ?? map?['data'] ?? response);
    final published = _asMap(map?['pagination']);
    final metadata = <String, dynamic>{
      ...?published,
      'page': published?['page'] ?? 1,
      'page_size': published?['page_size'] ?? safePageSize,
      if (map?['next'] != null || published?['next'] != null)
        'next': map?['next'] ?? published?['next'],
      if (map?['previous'] != null || published?['previous'] != null)
        'previous': map?['previous'] ?? published?['previous'],
    };
    return ApiPage(items: items, pagination: metadata);
  }

  /// Fetches a complete cursor-backed feed by following the server's `next`
  /// links. Notification history uses this contract and does not understand
  /// numeric `page` values, so routing it through [list] can repeatedly fetch
  /// the first page on a sufficiently long account history.
  Future<ApiPage> cursorList(
    String path, {
    Map<String, Object?>? query,
    int pageSize = 100,
  }) async {
    final safePageSize = pageSize.clamp(1, 100);
    final items = <Map<String, dynamic>>[];
    final itemKeys = <String>{};
    final seenCursors = <String>{};
    var pageQuery = <String, Object?>{...?query};
    String? next;

    // Keep a useful recent history without turning every app start/poll into
    // hundreds of requests on long-lived accounts. Older rows remain on the
    // server and can be exposed later through an explicit archive flow.
    for (var requestCount = 0; requestCount < 5; requestCount++) {
      final page = await cursorPage(
        path,
        query: pageQuery,
        pageSize: safePageSize,
      );
      for (final row in page.items) {
        final id = apiRecordId(row);
        final key = id.isEmpty ? jsonEncode(row) : id.toLowerCase();
        if (itemKeys.add(key)) items.add(row);
      }
      // Some deployments publish notifications as ordinary offset pages while
      // older ones use a raw cursor envelope. Detect the shape returned by the
      // server and continue numerically when pagination metadata is present.
      if (requestCount == 0 && page.pagination?['pages'] != null) {
        var currentPage = page.page;
        final pages = page.pages;
        while (currentPage < pages && currentPage < 5) {
          currentPage++;
          final numeric = await listPage(
            path,
            query: query,
            page: currentPage,
            pageSize: safePageSize,
          );
          for (final row in numeric.items) {
            final id = apiRecordId(row);
            final key = id.isEmpty ? jsonEncode(row) : id.toLowerCase();
            if (itemKeys.add(key)) items.add(row);
          }
          if (numeric.items.isEmpty) break;
        }
        next = currentPage < pages ? 'offset:$currentPage' : null;
        break;
      }
      next = apiText(page.pagination?['next']);
      if (next.isEmpty) break;
      final cursor = Uri.tryParse(next)?.queryParameters['cursor'];
      if (cursor == null || cursor.isEmpty || !seenCursors.add(cursor)) break;
      pageQuery = <String, Object?>{...?query, 'cursor': cursor};
    }

    return ApiPage(
      items: items,
      pagination: {
        'page': 1,
        'page_size': safePageSize,
        'total': items.length,
        'pages': 1,
        'has_next': next != null && next.isNotEmpty,
      },
    );
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
  'guardians',
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

/// Complete cursor-backed feeds. Unlike audit, reading notifications does not
/// itself append another notification, so following the full history is safe.
const Set<String> kApiCursorResources = {'notifications'};

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
  // The deployed contract protects guardian links as safeguarding records,
  // not as an ordinary parent directory.
  'guardians': 'safeguarding:write',
  'payments': 'payments:read',
  'invoices': 'finance:read',
  'attendanceRecords': 'attendance:read',
  'staff': 'users:read',
  'departments': 'org:read',
  'branches': 'org:read',
  'approvals': 'approvals:read',
  'meetings': 'meeting:read',
  // Messaging threads are participant-scoped by the endpoint itself.  The
  // published contract does not require an RBAC capability here, and
  // self-service profiles commonly publish an authoritative empty permission
  // list.  Gating this feed on `messaging:read` therefore hid valid student
  // and parent conversations without ever asking the server.
  'schedule': 'schedule:read',
  'studentRisk': 'intelligence:read',
  'audit': 'audit:read',
};

/// App-level authenticated session and live resource cache. It keeps no demo
/// data: after login, each page reads this exact server snapshot and mutations
/// reload only the affected resources.
class ApiSession extends ChangeNotifier {
  static const Duration _resourceFreshness = Duration(seconds: 30);

  final StarforgeApiClient client;
  final ApiSessionStorage sessionStorage;
  final Map<String, List<Map<String, dynamic>>> collections = {};
  final Map<String, Map<String, dynamic>> collectionPagination = {};
  final Map<String, ApiException> lastResourceErrors = {};
  final Map<String, dynamic> documents = {};
  final Map<String, DateTime> _loadedAt = {};
  final Map<String, Future<void>> _refreshInFlight = {};
  List<Map<String, dynamic>> messagingContacts = const [];
  int? messagingSelfUserId;
  DateTime? _rateLimitedUntil;
  ApiException? _rateLimitCause;
  Map<String, dynamic>? me;
  Set<String> _serverProfileFields = const {};
  bool loading = false;
  String? lastError;
  bool sessionPersistenceAvailable = true;
  int _sessionGeneration = 0;

  ApiSession({StarforgeApiClient? client, ApiSessionStorage? sessionStorage})
    : client = client ?? StarforgeApiClient(),
      sessionStorage = sessionStorage ?? MemoryApiSessionStorage() {
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
        'effective_permissions',
        'permission_codes',
        'capabilities',
        'grants',
      ]) {
        addValue(map[key]);
      }
    }

    for (final key in const [
      'permissions',
      'effective_permissions',
      'permission_codes',
      'capabilities',
      'grants',
      'role',
      'roles',
      'scopes',
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
            'effective_permissions',
            'permission_codes',
            'capabilities',
            'grants',
            'scopes',
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

  /// Student and parent credentials are intentionally bootstrapped with only
  /// their own communication feeds. Older deployments omit permission arrays
  /// from `/users/me/`; treating that omission as permission to preload every
  /// staff directory made self-service login slow and could trigger throttles.
  bool get _isSelfServicePrincipal {
    final profile = me;
    if (profile == null) return false;
    final aliases = <String>{};

    void collect(Object? value) {
      if (value is Iterable && value is! String) {
        for (final item in value) {
          collect(item);
        }
        return;
      }
      final map = _asMap(value);
      if (map != null) {
        if (map['is_active'] == false) return;
        for (final key in const [
          'principal_kind',
          'account_kind',
          'account_type_slug',
          'role',
          'role_name',
          'role_slug',
          'user_role',
          'slug',
          'name',
          'code',
        ]) {
          collect(map[key]);
        }
        collect(map['role_memberships']);
        return;
      }
      if (value == null) return;
      final normalized = apiText(
        value,
      ).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
      if (normalized.isNotEmpty) aliases.add(normalized);
    }

    collect({
      for (final key in const [
        'principal_kind',
        'account_kind',
        'account_type_slug',
        'role',
        'role_name',
        'role_slug',
        'user_role',
        'role_memberships',
      ])
        key: profile[key],
    });
    return aliases.any(
      (value) => const {
        'student',
        'learner',
        'pupil',
        'parent',
        'guardian',
        'caregiver',
      }.contains(value),
    );
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
    _sessionGeneration++;
    collections.clear();
    collectionPagination.clear();
    lastResourceErrors.clear();
    documents.clear();
    messagingContacts = const [];
    messagingSelfUserId = null;
    me = null;
    _serverProfileFields = const {};
    _clearRequestState();
    lastError = 'Session expired. Sign in again.';
    unawaited(_clearPersistedSession());
    notifyListeners();
  }

  Future<void> _persistSession() async {
    final token = client.token;
    final profile = me;
    if (token == null || token.isEmpty || profile == null) return;
    try {
      await sessionStorage.write(
        PersistedApiSession(
          baseUrl: client.baseUrl,
          token: token,
          profile: Map<String, dynamic>.from(profile),
          serverProfileFields: _serverProfileFields.toList(growable: false),
        ),
      );
      sessionPersistenceAvailable = true;
    } catch (_) {
      // A keystore failure must not discard an otherwise valid live login.
      sessionPersistenceAvailable = false;
    }
  }

  Future<void> _clearPersistedSession() async {
    try {
      await sessionStorage.clear();
      sessionPersistenceAvailable = true;
    } catch (_) {
      sessionPersistenceAvailable = false;
    }
  }

  /// Restores the encrypted bearer session without ever persisting a password.
  /// Temporary network/server failures keep the cached account identity so the
  /// user is not signed out merely because the device started offline. A 401
  /// or otherwise invalid account boundary clears the saved session.
  Future<bool> restore({String language = 'uz'}) async {
    if (loading) return authenticated && me != null;
    loading = true;
    lastError = null;
    notifyListeners();
    PersistedApiSession? saved;
    try {
      saved = await sessionStorage.read();
      sessionPersistenceAvailable = true;
    } catch (_) {
      sessionPersistenceAvailable = false;
      loading = false;
      notifyListeners();
      return false;
    }
    if (saved == null) {
      loading = false;
      notifyListeners();
      return false;
    }

    client.configure(
      baseUrl: saved.baseUrl,
      language: language,
      token: saved.token,
    );
    _sessionGeneration++;
    me = Map<String, dynamic>.from(saved.profile);
    _updateMessagingIdentity();
    _serverProfileFields = Set<String>.unmodifiable(saved.serverProfileFields);
    try {
      final profile = _asMap(await client.request('GET', '/api/v1/users/me/'));
      if (profile == null) {
        throw ApiException(
          status: _HttpStatus.badGateway,
          message: 'The server returned an invalid account profile.',
          code: 'invalid_profile_response',
          requestId: _requestId(),
        );
      }
      _serverProfileFields = Set<String>.unmodifiable(profile.keys);
      // Older deployments omit gender/birthdate. Preserve their encrypted app
      // preferences while every field returned by this server stays
      // authoritative.
      me = <String, dynamic>{
        for (final key in const ['gender', 'birthdate'])
          if (!profile.containsKey(key) && saved.profile.containsKey(key))
            key: saved.profile[key],
        ...profile,
      };
      _updateMessagingIdentity();
      await _persistSession();
      loading = false;
      notifyListeners();
      unawaited(_bootstrapAfterAuthentication(_sessionGeneration));
      return true;
    } on ApiException catch (error) {
      final temporary =
          error.code != 'invalid_profile_response' &&
          (error.status == 0 ||
              error.status == _HttpStatus.tooManyRequests ||
              error.status >= 500);
      if (temporary && client.hasSession && saved.profile.isNotEmpty) {
        me = Map<String, dynamic>.from(saved.profile);
        _serverProfileFields = Set<String>.unmodifiable(
          saved.serverProfileFields,
        );
        lastError = error.message;
        return true;
      }
      _clearLoginState();
      await _clearPersistedSession();
      return false;
    } catch (_) {
      // Unexpected/corrupt responses fail closed and require a fresh login.
      _clearLoginState();
      await _clearPersistedSession();
      return false;
    } finally {
      if (loading) {
        loading = false;
        notifyListeners();
      }
    }
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

  bool isRefreshing(String resource) => _refreshInFlight.containsKey(resource);

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
    if (kApiSinglePageResources.contains(resource)) {
      return client.cursorPage(path, query: parameters, pageSize: 100);
    }
    if (kApiCursorResources.contains(resource)) {
      return client.cursorList(path, query: parameters, pageSize: 100);
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
    return kApiSinglePageResources.contains(resource) ||
            kApiCursorResources.contains(resource)
        ? client.cursorPage(path, query: parameters, pageSize: pageSize)
        : client.listPage(
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
    final parentIdentities = _recordIdentity(
      parent,
      extraKeys: const ['parent_id', 'parent_name'],
    );
    final guardianLinks = records('guardians').where(
      (row) => _relatedTo(row, parentIdentities, const [
        'parent',
        'parent_id',
        'parent_name',
        'guardian',
        'guardian_id',
        'guardian_name',
      ]),
    );
    final guardianChildren = <Map<String, dynamic>>[];
    for (final link in guardianLinks) {
      final embeddedStudent = apiValue(link, const ['student', 'child']);
      if (embeddedStudent is Map) {
        guardianChildren.add(Map<String, dynamic>.from(embeddedStudent));
      }
      final studentIdentities = _identityTokens(
        apiValue(link, const [
          'student',
          'student_id',
          'student_name',
          'child',
          'child_id',
          'child_name',
        ]),
      );
      guardianChildren.addAll(
        records('students').where(
          (student) => _recordIdentity(
            student,
            extraKeys: const ['student_id', 'student_name'],
          ).any(studentIdentities.contains),
        ),
      );
    }
    return _deduplicate([...embedded, ...related, ...guardianChildren]);
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
      _sessionGeneration++;
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
      _serverProfileFields = Set<String>.unmodifiable(me!.keys);
      _updateMessagingIdentity();
      await _persistSession();
      // Authentication is complete once the login boundary and `/users/me/`
      // both succeed. Do not keep the user on the login screen while every
      // dashboard collection is fetched. The authenticated workspace starts
      // empty and is hydrated by this best-effort background bootstrap.
      loading = false;
      notifyListeners();
      unawaited(_bootstrapAfterAuthentication(_sessionGeneration));
    } on ApiException catch (error) {
      _clearLoginState();
      await _clearPersistedSession();
      lastError = error.message;
      rethrow;
    } catch (error) {
      _clearLoginState();
      await _clearPersistedSession();
      final wrapped = ApiException(
        status: 0,
        message: 'Unexpected login failure (${error.runtimeType}).',
        code: 'login_client_error',
        requestId: _requestId(),
      );
      lastError = wrapped.message;
      throw wrapped;
    } finally {
      if (loading) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _bootstrapAfterAuthentication(int generation) async {
    try {
      await reloadAll();
    } on ApiException catch (error) {
      // A collection-level failure is rendered by the owning page. Login has
      // already succeeded, so an optional slow/unavailable resource must not
      // hold the authentication form open.
      if (authenticated && generation == _sessionGeneration) {
        lastError = error.message;
        notifyListeners();
      }
    } catch (_) {
      if (authenticated && generation == _sessionGeneration) {
        lastError = 'Some data could not be loaded.';
        notifyListeners();
      }
    }
  }

  void _clearLoginState() {
    _sessionGeneration++;
    client.clearSession();
    collections.clear();
    collectionPagination.clear();
    lastResourceErrors.clear();
    documents.clear();
    messagingContacts = const [];
    messagingSelfUserId = null;
    me = null;
    _serverProfileFields = const {};
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
    try {
      final refreshed = _asMap(
        await client.request('GET', '/api/v1/users/me/'),
      );
      if (refreshed != null) {
        _serverProfileFields = Set<String>.unmodifiable(refreshed.keys);
      }
      me = <String, dynamic>{...?me, ...?refreshed};
    } on ApiException {
      me = <String, dynamic>{...?me, 'must_change_password': false};
    }
    await _persistSession();
    notifyListeners();
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
    final generation = _sessionGeneration;
    const selfServiceBootstrap = {'threads', 'notifications'};
    final entries = kApiResources.entries
        .where(
          (entry) =>
              kApiBootstrapResources.contains(entry.key) &&
              (!_isSelfServicePrincipal ||
                  selfServiceBootstrap.contains(entry.key)) &&
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
    if (!authenticated || generation != _sessionGeneration) return;
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
    await _reloadDocuments(generation: generation);
    if (!authenticated || generation != _sessionGeneration) return;
    _updateMessagingIdentity();
    await _reloadMessagingDirectory(generation: generation);
    if (!authenticated || generation != _sessionGeneration) return;
    notifyListeners();
  }

  void _updateMessagingIdentity() {
    final profile = me;
    if (profile == null) {
      messagingSelfUserId = null;
      return;
    }
    final raw = apiValue(profile, const [
      // Messaging has its own user namespace on the live backend.  A staff
      // profile id (for example CEO profile 4) is not the same value as the
      // messaging participant id (for example user 10).
      'messaging_user_id',
      'user_id',
      'account_id',
      'user',
      'account',
      'id',
    ]);
    final nested = _asMap(raw);
    messagingSelfUserId = _asInt(
      nested == null
          ? raw
          : apiValue(nested, const ['user_id', 'account_id', 'id', 'pk']),
    );
  }

  Future<void> _reloadMessagingDirectory({required int generation}) async {
    if (!_mayReadResource('threads')) return;
    try {
      final page = await client.list(
        '/api/v1/messaging/contacts/',
        query: const {'page_size': 100},
      );
      if (!authenticated || generation != _sessionGeneration) return;
      final participantIds = <String>{};
      for (final thread in records('threads')) {
        final rawParticipants = apiValue(thread, const [
          'participants',
          'participant_ids',
          'members',
        ]);
        if (rawParticipants is! Iterable || rawParticipants is String) {
          continue;
        }
        for (final participant in rawParticipants) {
          final map = _asMap(participant);
          final id = apiText(
            map == null
                ? participant
                : apiValue(map, const ['user', 'user_id', 'id', 'pk']),
          );
          if (id.isNotEmpty) participantIds.add(id);
        }
      }
      final enriched = <Map<String, dynamic>>[];
      for (final contact in page.items) {
        final contactId = apiText(
          apiValue(contact, const ['user_id', 'user', 'id', 'pk']),
        );
        enriched.add(
          participantIds.contains(contactId)
              ? await _contactWithPublishedAvatar(contact)
              : contact,
        );
      }
      if (!authenticated || generation != _sessionGeneration) return;
      messagingContacts = enriched;
      final directorySelfId = _asInt(page.pagination?['self_user_id']);
      if (directorySelfId != 0) messagingSelfUserId = directorySelfId;
    } on ApiException catch (error) {
      _rememberRateLimit(error);
      // The supplied schema does not yet advertise the directory. Older
      // deployments remain usable through profile identity/thread subjects.
      if (error.status != _HttpStatus.notFound &&
          error.status != _HttpStatus.forbidden &&
          error.status != 405) {
        lastResourceErrors['threads'] = error;
      }
    }
  }

  /// The compact messaging directory intentionally contains identity and
  /// presence only. For student contacts that already participate in a chat,
  /// the leadership profile is the published source of the photo download
  /// URL. Fetching only active participants avoids one request per student in
  /// large tenants while still allowing real avatars in the conversation UI.
  Future<Map<String, dynamic>> _contactWithPublishedAvatar(
    Map<String, dynamic> contact,
  ) async {
    final existing = apiText(
      apiValue(contact, const [
        'avatar_url',
        'profile_photo_url',
        'photo_url',
        'image_url',
      ]),
    );
    if (existing.isNotEmpty) return contact;
    final kind = apiText(
      apiValue(contact, const ['principal_kind', 'category', 'role_slug']),
    ).toLowerCase();
    if (kind != 'student') return contact;
    final profileId = apiText(
      apiValue(contact, const ['profile_id', 'principal_id', 'student_id']),
    );
    if (profileId.isEmpty) return contact;
    try {
      final profile = _asMap(
        await client.request(
          'GET',
          '/api/v1/students/${Uri.encodeComponent(profileId)}/leadership-profile/',
        ),
      );
      final identity = _asMap(profile?['identity']);
      final photo = _asMap(identity?['photo']);
      final url = apiText(
        apiValue(photo ?? const <String, dynamic>{}, const [
          'download_url',
          'url',
          'file_url',
        ]),
      );
      if (url.isEmpty) return contact;
      return <String, dynamic>{...contact, 'avatar_url': url};
    } on ApiException catch (error) {
      _rememberRateLimit(error);
      return contact;
    }
  }

  @visibleForTesting
  void updateMessagingIdentityForTest() => _updateMessagingIdentity();

  Future<ApiPage> _loadCollection(String name, String path) {
    if (kApiSinglePageResources.contains(name)) {
      return client.cursorPage(path, pageSize: 100);
    }
    if (kApiCursorResources.contains(name)) {
      return client.cursorList(path, pageSize: 100);
    }
    return client.list(path);
  }

  Future<void> _reloadDocuments({int? generation}) async {
    final expectedGeneration = generation ?? _sessionGeneration;
    const selfServiceDocuments = {'unreadNotifications'};
    final values = await Future.wait(
      kApiDocuments.entries
          .where(
            (entry) =>
                kApiBootstrapDocuments.contains(entry.key) &&
                (!_isSelfServicePrincipal ||
                    selfServiceDocuments.contains(entry.key)) &&
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
    if (!authenticated || expectedGeneration != _sessionGeneration) return;
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

  /// Refresh only the newest cursor page used by background notification
  /// polling. It merges the head with the bounded local history so polling
  /// cannot repeatedly download every notification or trigger API throttling.
  Future<void> refreshNotificationHead() async {
    const collection = 'notifications';
    final inFlight = _refreshInFlight[collection];
    if (inFlight != null) return inFlight;
    final rateLimit = _activeRateLimit();
    if (rateLimit != null) return Future<void>.error(rateLimit);

    final future = () async {
      try {
        final page = await client.cursorPage(
          kApiResources[collection]!,
          pageSize: 100,
        );
        final merged = _deduplicate([
          ...page.items,
          ...records(collection),
        ]).take(500).toList(growable: false);
        collections[collection] = merged;
        collectionPagination[collection] = {
          ...?page.pagination,
          'page': 1,
          'page_size': 100,
          'total': merged.length,
        };
        lastResourceErrors.remove(collection);
        _loadedAt[collection] = DateTime.now();
        notifyListeners();
      } on ApiException catch (error) {
        _rememberRateLimit(error);
        lastResourceErrors[collection] = error;
        notifyListeners();
        rethrow;
      }
    }();
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
        if (collection == 'threads') {
          // A thread subject is not a participant name. Refresh the
          // authoritative messaging directory in the same transaction so a
          // newly created/external conversation cannot remain labelled with
          // a technical subject such as "Chat verification".
          await _reloadMessagingDirectory(generation: _sessionGeneration);
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

  /// Resolve the actual user account behind a student/staff profile before a
  /// direct-message thread is created. Student list serializers used by the
  /// deployed backend expose `username` but do not expose the related user
  /// primary key, while messaging correctly requires that user id. Looking up
  /// an exact account here avoids substituting a student profile id and keeps
  /// presence (`last_seen_at`) tied to the authoritative user record.
  Future<Map<String, dynamic>?> resolveMessagingContact({
    Object? userId,
    String? username,
    String? fullName,
  }) async {
    final requestedId = apiText(userId);
    final rawUsername = apiText(username).trim();
    final requestedUsername =
        const {'', '—', '-', 'null'}.contains(rawUsername.toLowerCase())
        ? ''
        : rawUsername.toLowerCase();
    final requestedName = apiText(fullName).toLowerCase();

    bool matches(Map<String, dynamic> row) {
      final id = apiRecordId(row);
      final messagingId = apiText(
        apiValue(row, const ['user_id', 'account_id', 'user', 'id', 'pk']),
      );
      final accountUsername = apiText(
        apiValue(row, const [
          'username',
          'login',
          'phone',
          'email',
          'identifier',
        ]),
      ).toLowerCase();
      var accountName = apiText(
        apiValue(row, const ['full_name', 'name', 'display_name']),
      ).toLowerCase();
      if (accountName.isEmpty) {
        accountName = [
          apiText(row['first_name']),
          apiText(row['middle_name']),
          apiText(row['last_name']),
        ].where((part) => part.isNotEmpty).join(' ').toLowerCase();
      }
      if (requestedId.isNotEmpty &&
          (messagingId == requestedId || id == requestedId)) {
        return true;
      }
      if (requestedUsername.isNotEmpty &&
          accountUsername == requestedUsername) {
        return true;
      }
      return requestedUsername.isEmpty &&
          requestedName.isNotEmpty &&
          accountName == requestedName;
    }

    Map<String, dynamic>? cachedMatch() {
      for (final row in messagingContacts) {
        if (matches(row)) return row;
      }
      for (final row in records('users')) {
        if (matches(row)) return row;
      }
      return null;
    }

    Future<Map<String, dynamic>> publishContact(
      Map<String, dynamic> row,
    ) async {
      final enriched = await _contactWithPublishedAvatar(row);
      final id = apiRecordId(enriched);
      final index = messagingContacts.indexWhere(
        (candidate) => id.isNotEmpty && apiRecordId(candidate) == id,
      );
      if (index < 0) {
        messagingContacts = <Map<String, dynamic>>[
          ...messagingContacts,
          enriched,
        ];
      } else if (!mapEquals(messagingContacts[index], enriched)) {
        final updated = [...messagingContacts];
        updated[index] = enriched;
        messagingContacts = updated;
      }
      return enriched;
    }

    void cache(Map<String, dynamic> row) {
      final users = collections.putIfAbsent(
        'users',
        () => <Map<String, dynamic>>[],
      );
      final id = apiRecordId(row);
      final index = users.indexWhere(
        (candidate) => id.isNotEmpty && apiRecordId(candidate) == id,
      );
      if (index < 0) {
        users.add(row);
      } else {
        users[index] = row;
      }
    }

    final cached = cachedMatch();
    if (cached != null) return publishContact(cached);

    if (requestedId.isNotEmpty) {
      try {
        final record = await detail('users', requestedId);
        // Never replace a known messaging id with an unrelated profile row
        // returned by a permissive/legacy detail route.
        if (record != null && matches(record)) {
          cache(record);
          return publishContact(record);
        }
      } on ApiException catch (error) {
        if (error.status != _HttpStatus.notFound &&
            error.status != _HttpStatus.forbidden) {
          rethrow;
        }
      }
    }

    final searches = <String>{
      if (requestedUsername.isNotEmpty) requestedUsername,
      if (requestedName.isNotEmpty) requestedName,
    };
    // The deployed messaging service publishes bridge-user ids and real
    // presence here. It is a better source than `/users/` (which some roles
    // cannot read) and avoids confusing profile ids with participant ids.
    for (final search in searches) {
      try {
        final page = await client.list(
          '/api/v1/messaging/contacts/',
          query: {'search': search, 'page_size': 50},
        );
        messagingContacts = <Map<String, dynamic>>[
          ...messagingContacts.where(
            (cached) => !page.items.any(
              (fresh) => apiRecordId(fresh) == apiRecordId(cached),
            ),
          ),
          ...page.items,
        ];
        for (final row in page.items) {
          if (matches(row)) return publishContact(row);
        }
      } on ApiException catch (error) {
        // Keep compatibility with the supplied schema, which does not yet
        // advertise this endpoint, by falling through to `/users/` only when
        // contacts is genuinely unavailable to the current deployment/role.
        if (error.status != _HttpStatus.notFound &&
            error.status != _HttpStatus.forbidden &&
            error.status != 405) {
          rethrow;
        }
      }
    }
    for (final search in searches) {
      final page = await client.list(
        '/api/v1/users/',
        query: {'search': search, 'page_size': 50},
      );
      for (final row in page.items) {
        cache(row);
        if (matches(row)) return publishContact(row);
      }
    }
    return null;
  }

  /// Update only the current account's published self-service fields.
  /// Role, permissions, username and activation state are intentionally not
  /// accepted here. Merging the response keeps permission metadata that some
  /// legacy deployments omit from PATCH while returning it from GET.
  Future<Map<String, dynamic>> updateMe(Map<String, Object?> changes) async {
    const serverWritable = <String>{
      'first_name',
      'last_name',
      'middle_name',
      'phone',
      'email',
    };
    const optionalProfileFields = <String>{'birthdate', 'gender'};
    final requestedOptional = changes.keys
        .where(optionalProfileFields.contains)
        .toSet();
    if (requestedOptional.isNotEmpty && _serverProfileFields.isEmpty) {
      final refreshed = _asMap(
        await client.request('GET', '/api/v1/users/me/'),
      );
      if (refreshed == null) {
        throw ApiException(
          status: _HttpStatus.badGateway,
          code: 'invalid_profile_response',
          message: 'The server returned an invalid account profile.',
          requestId: _requestId(),
        );
      }
      _serverProfileFields = Set<String>.unmodifiable(refreshed.keys);
      me = <String, dynamic>{...?me, ...refreshed};
    }
    final unsupported = requestedOptional.difference(_serverProfileFields);
    if (unsupported.isNotEmpty) {
      throw ApiException(
        status: _HttpStatus.badRequest,
        code: 'profile_field_not_supported',
        message:
            'This server does not support updating: ${unsupported.join(', ')}.',
        errors: {
          for (final field in unsupported)
            field: ['This field is not published by /users/me/.'],
        },
        requestId: _requestId(),
      );
    }
    final body = <String, Object?>{
      for (final entry in changes.entries)
        if (serverWritable.contains(entry.key) ||
            optionalProfileFields.contains(entry.key) &&
                _serverProfileFields.contains(entry.key))
          entry.key: entry.value,
    };
    final result = body.isEmpty
        ? null
        : _asMap(
            await client.request('PATCH', '/api/v1/users/me/', body: body),
          );
    me = <String, dynamic>{...?me, ...?result};
    if (result != null) {
      _serverProfileFields = Set<String>.unmodifiable({
        ..._serverProfileFields,
        ...result.keys,
      });
    }
    await _persistSession();
    notifyListeners();
    return Map<String, dynamic>.unmodifiable(me!);
  }

  /// Whether the active `/users/me/` contract publishes a writable profile
  /// field. Optional demographic inputs are hidden when a deployment does not
  /// expose them, instead of allowing a form submission that must fail.
  bool supportsProfileField(String field) {
    const core = <String>{
      'first_name',
      'last_name',
      'middle_name',
      'phone',
      'email',
    };
    return core.contains(field) ||
        _serverProfileFields.contains(field) ||
        (me?.containsKey(field) ?? false);
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

  Future<ApiPage> threadMessages(
    Object threadId, {
    int page = 1,
    int pageSize = 50,
  }) {
    final id = Uri.encodeComponent(threadId.toString().trim());
    if (id.isEmpty) {
      throw ArgumentError.value(threadId, 'threadId', 'Missing thread id');
    }
    return client.listPage(
      '/api/v1/messaging/threads/$id/messages/',
      page: page,
      pageSize: pageSize,
    );
  }

  /// Returns the backend's newest bounded message page.
  ///
  /// The deployed endpoint is oldest-first and currently ignores
  /// `ordering=-created_at`. Page one therefore contains old messages in a
  /// long conversation. Read it once for the authoritative page count and
  /// request the last page when necessary.
  Future<ApiPage> latestThreadMessages(
    Object threadId, {
    int pageSize = 50,
  }) async {
    final first = await threadMessages(threadId, page: 1, pageSize: pageSize);
    final latestPage = first.pages;
    if (latestPage <= 1) return first;
    return threadMessages(threadId, page: latestPage, pageSize: pageSize);
  }

  Future<Map<String, dynamic>?> rereadThreadMessage(
    Object threadId,
    Object messageId,
  ) async {
    final wanted = messageId.toString().trim();
    if (wanted.isEmpty) return null;
    final page = await latestThreadMessages(threadId);
    for (final row in page.items) {
      if (apiRecordId(row) == wanted) return row;
    }
    return null;
  }

  Future<Map<String, dynamic>?> sendThreadMessage(
    Object threadId,
    String text, {
    List<String> attachments = const [],
  }) async {
    final id = Uri.encodeComponent(threadId.toString().trim());
    final body = text.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(threadId, 'threadId', 'Missing thread id');
    }
    if (body.isEmpty && attachments.isEmpty) {
      throw ArgumentError.value(text, 'text', 'Message is empty');
    }
    final result = await client.request(
      'POST',
      '/api/v1/messaging/threads/$id/messages/',
      body: {'body': body, 'attachments': attachments},
    );
    return _asMap(result);
  }

  Future<Map<String, dynamic>?> editMessage(
    Object messageId,
    String text,
  ) async {
    final id = Uri.encodeComponent(messageId.toString().trim());
    final body = text.trim();
    if (id.isEmpty || body.isEmpty) {
      throw ArgumentError('Message id and body are required');
    }
    return _asMap(
      await client.request(
        'PATCH',
        '/api/v1/messaging/messages/$id/',
        body: {'body': body},
      ),
    );
  }

  Future<void> deleteServerMessage(Object messageId) async {
    final id = Uri.encodeComponent(messageId.toString().trim());
    if (id.isEmpty) throw ArgumentError('Message id is required');
    await client.request('DELETE', '/api/v1/messaging/messages/$id/');
  }

  Future<void> addMessageReaction(Object messageId, String emoji) async {
    final id = Uri.encodeComponent(messageId.toString().trim());
    final value = emoji.trim();
    if (id.isEmpty || value.isEmpty) {
      throw ArgumentError('Message id and emoji are required');
    }
    await client.request(
      'POST',
      '/api/v1/messaging/messages/$id/reactions/',
      body: {'emoji': value},
    );
  }

  Future<void> removeMessageReaction(Object messageId, String emoji) async {
    final id = Uri.encodeComponent(messageId.toString().trim());
    final value = Uri.encodeComponent(emoji.trim());
    if (id.isEmpty || value.isEmpty) {
      throw ArgumentError('Message id and emoji are required');
    }
    await client.request(
      'DELETE',
      '/api/v1/messaging/messages/$id/reactions/$value/',
    );
  }

  Future<void> markThreadRead(Object threadId) async {
    final id = Uri.encodeComponent(threadId.toString().trim());
    if (id.isEmpty) {
      throw ArgumentError.value(threadId, 'threadId', 'Missing thread id');
    }
    await client.request(
      'POST',
      '/api/v1/messaging/threads/$id/read/',
      body: const <String, Object?>{},
    );
  }

  Future<Map<String, dynamic>?> createMessageThread({
    required List<int> participantIds,
    required String subject,
    required String firstBody,
    List<String> attachments = const [],
  }) async {
    if (participantIds.isEmpty) {
      throw ArgumentError.value(
        participantIds,
        'participantIds',
        'At least one participant is required',
      );
    }
    final result = _asMap(
      await action(
        'POST',
        '/api/v1/messaging/threads/',
        body: {
          'participant_ids': participantIds,
          if (subject.trim().isNotEmpty) 'subject': subject.trim(),
          if (firstBody.trim().isNotEmpty) 'first_body': firstBody.trim(),
          if (attachments.isNotEmpty) 'attachments': attachments,
        },
      ),
    );
    final threadId = result == null ? '' : apiRecordId(result);
    if (threadId.isEmpty) {
      // Without the created id the client cannot safely send or retry the
      // first message: another POST could create a duplicate conversation.
      await refresh('threads', force: true);
      throw ApiException(
        status: 0,
        code: 'invalid_thread_response',
        message: 'The server created a chat without returning its id.',
        requestId: _requestId(),
      );
    }
    // `first_body` makes creation atomic: a network failure can no longer
    // leave an empty direct thread followed by a duplicate retry. The current
    // backend creates the first message in the same transaction.
    try {
      await refresh('threads', force: true);
    } on ApiException {
      // The atomic POST already created both the direct thread and its first
      // message. A transient/rate-limited follow-up refresh must not turn that
      // success into a retryable failure and create a duplicate conversation.
    }
    return result;
  }

  Future<String> uploadMessageAttachment({
    required String filename,
    required String contentType,
    required Uint8List bytes,
  }) async {
    final grant = _asMap(
      await client.request(
        'POST',
        '/api/v1/messaging/attachments/upload-url/',
        body: {
          'filename': filename,
          'content_type': contentType,
          'size_bytes': bytes.length,
        },
      ),
    );
    final url = apiText(grant?['url']);
    final key = apiText(grant?['key']);
    final rawFields = grant?['fields'];
    final fields = rawFields is Map
        ? <String, String>{
            for (final entry in rawFields.entries)
              '${entry.key}': '${entry.value}',
          }
        : const <String, String>{};
    final method = apiText(
      apiValue(grant ?? const <String, dynamic>{}, const [
        'method',
        'http_method',
        'upload_method',
      ]),
      fallback: fields.isEmpty ? 'PUT' : 'POST',
    ).toUpperCase();
    if (url.isEmpty || key.isEmpty || (method != 'POST' && method != 'PUT')) {
      throw ApiException(
        status: _HttpStatus.badGateway,
        code: 'invalid_upload_grant',
        message: 'The server returned an invalid attachment upload grant.',
        requestId: _requestId(),
      );
    }
    if (method == 'PUT') {
      await client.uploadPutBytes(
        url,
        bytes,
        contentType: contentType,
        headers: fields,
      );
    } else {
      await client.uploadMultipartBytes(
        url,
        bytes,
        filename: filename,
        contentType: contentType,
        fields: fields,
      );
    }
    return key;
  }

  Future<String> messageAttachmentDownloadUrl(
    Object threadId,
    String key,
  ) async {
    final id = Uri.encodeComponent(threadId.toString().trim());
    final value = key.trim();
    if (id.isEmpty || value.isEmpty) {
      throw ArgumentError('Thread id and attachment key are required');
    }
    final direct = Uri.tryParse(value);
    if (direct != null && direct.hasScheme && direct.hasAuthority) return value;
    final result = _asMap(
      await client.request(
        'GET',
        '/api/v1/messaging/threads/$id/attachments/download/',
        query: {'key': value},
      ),
    );
    final url = apiText(result?['url']);
    final parsed = Uri.tryParse(url);
    if (parsed == null || !parsed.hasScheme || !parsed.hasAuthority) {
      throw ApiException(
        status: _HttpStatus.badGateway,
        code: 'invalid_attachment_download',
        message: 'The server did not return an attachment download URL.',
        requestId: _requestId(),
      );
    }
    return url;
  }

  Future<void> setThreadMuted(Object threadId, bool muted) async {
    final id = Uri.encodeComponent(threadId.toString().trim());
    if (id.isEmpty) {
      throw ArgumentError.value(threadId, 'threadId', 'Missing thread id');
    }
    await client.request(
      'PATCH',
      '/api/v1/messaging/threads/$id/preferences/',
      body: {'notifications_muted': muted},
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
      _sessionGeneration++;
      client.clearSession();
      collections.clear();
      collectionPagination.clear();
      lastResourceErrors.clear();
      documents.clear();
      messagingContacts = const [];
      messagingSelfUserId = null;
      me = null;
      _serverProfileFields = const {};
      _clearRequestState();
      await _clearPersistedSession();
      loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    // Invalidate every background bootstrap before ChangeNotifier becomes
    // unusable. Late network completions will observe the generation mismatch
    // and return without touching caches or notifying a disposed session.
    _sessionGeneration++;
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
