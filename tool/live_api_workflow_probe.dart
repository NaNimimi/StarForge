import 'dart:async';
import 'dart:convert';
import 'dart:io';

Map<String, dynamic>? _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

String? _scalar(Object? value) {
  if (value is! String && value is! num && value is! bool) return null;
  final text = '$value'.trim();
  return text.isEmpty ? null : text;
}

String? _findValue(Object? value, Set<String> wanted, [int depth = 0]) {
  if (depth > 8) return null;
  if (value is Map) {
    for (final entry in value.entries) {
      if (wanted.contains('${entry.key}'.toLowerCase())) {
        final direct = _scalar(entry.value);
        if (direct != null) return direct;
      }
    }
    for (final child in value.values) {
      final found = _findValue(child, wanted, depth + 1);
      if (found != null) return found;
    }
  } else if (value is Iterable && value is! String) {
    for (final child in value) {
      final found = _findValue(child, wanted, depth + 1);
      if (found != null) return found;
    }
  }
  return null;
}

class ProbeResponse {
  const ProbeResponse({
    required this.status,
    required this.requestId,
    required this.payload,
    required this.headers,
  });

  final int status;
  final String requestId;
  final Object? payload;
  final HttpHeaders headers;

  bool get succeeded => status >= 200 && status < 300;
}

class LiveProbe {
  LiveProbe({
    required this._baseUri,
    required this.minimumInterval,
    this.hostHeader,
  });

  Uri _baseUri;
  final Duration minimumInterval;
  final String? hostHeader;
  String? token;
  int _requestNumber = 0;
  DateTime? _lastRequestStartedAt;

  Future<ProbeResponse> request(
    String method,
    String path, {
    Object? body,
    bool authenticate = true,
    int redirectsLeft = 2,
    int transportRetries = 1,
  }) async {
    final previousRequest = _lastRequestStartedAt;
    if (previousRequest != null) {
      final elapsed = DateTime.now().difference(previousRequest);
      if (elapsed < minimumInterval) {
        await Future<void>.delayed(minimumInterval - elapsed);
      }
    }
    _lastRequestStartedAt = DateTime.now();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final normalizedPath = path.startsWith('/') ? path : '/$path';
      final uri = _baseUri.resolve(normalizedPath);
      final requestId =
          'workflow-${DateTime.now().microsecondsSinceEpoch}-${++_requestNumber}';
      final httpRequest = await client
          .openUrl(method, uri)
          .timeout(const Duration(seconds: 20));
      httpRequest.followRedirects = false;
      httpRequest.headers
        ..set(HttpHeaders.acceptHeader, 'application/json')
        ..set(HttpHeaders.acceptLanguageHeader, 'en')
        ..set('X-Request-ID', requestId);
      if (hostHeader != null && hostHeader!.trim().isNotEmpty) {
        httpRequest.headers.set(HttpHeaders.hostHeader, hostHeader!.trim());
      }
      if (authenticate && token != null) {
        httpRequest.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $token',
        );
      }
      if (body != null) {
        final encoded = utf8.encode(jsonEncode(body));
        httpRequest.headers
          ..contentType = ContentType.json
          ..contentLength = encoded.length;
        httpRequest.add(encoded);
      }
      final response = await httpRequest.close().timeout(
        const Duration(seconds: 30),
      );
      final bytes = await response
          .fold<List<int>>(<int>[], (all, chunk) => all..addAll(chunk))
          .timeout(const Duration(seconds: 30));
      final responseText = utf8.decode(bytes, allowMalformed: true).trim();
      Object? payload;
      if (responseText.isNotEmpty) {
        try {
          payload = jsonDecode(responseText);
        } on FormatException {
          payload = responseText;
        }
      }
      final responseRequestId =
          response.headers.value('x-request-id') ?? requestId;
      final result = ProbeResponse(
        status: response.statusCode,
        requestId: responseRequestId,
        payload: payload,
        headers: response.headers,
      );

      if (const {301, 302, 307, 308}.contains(result.status) &&
          redirectsLeft > 0) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location != null && location.trim().isNotEmpty) {
          final redirected = uri.resolve(location);
          _baseUri = Uri(
            scheme: redirected.scheme,
            userInfo: redirected.userInfo,
            host: redirected.host,
            port: redirected.hasPort ? redirected.port : null,
            path: '/',
          );
          return request(
            method,
            path,
            body: body,
            authenticate: authenticate,
            redirectsLeft: redirectsLeft - 1,
          );
        }
      }
      return result;
    } on SocketException {
      if (transportRetries <= 0) rethrow;
      await Future<void>.delayed(const Duration(seconds: 2));
      return request(
        method,
        path,
        body: body,
        authenticate: authenticate,
        redirectsLeft: redirectsLeft,
        transportRetries: transportRetries - 1,
      );
    } on TimeoutException {
      if (transportRetries <= 0) rethrow;
      await Future<void>.delayed(const Duration(seconds: 2));
      return request(
        method,
        path,
        body: body,
        authenticate: authenticate,
        redirectsLeft: redirectsLeft,
        transportRetries: transportRetries - 1,
      );
    } finally {
      client.close(force: true);
    }
  }
}

Never _missing(String name) {
  stderr.writeln('Missing required environment variable: $name');
  exit(64);
}

String _requiredEnvironment(String name) {
  final value = Platform.environment[name]?.trim() ?? '';
  if (value.isEmpty) _missing(name);
  return value;
}

String _errorText(ProbeResponse response) {
  final payload = _map(response.payload);
  final code =
      _scalar(payload?['code']) ?? _scalar(_map(payload?['error'])?['code']);
  final message =
      _scalar(payload?['message']) ??
      _scalar(payload?['detail']) ??
      _scalar(_map(payload?['error'])?['message']) ??
      'HTTP ${response.status}';
  return '${code == null ? '' : '$code: '}$message';
}

Object? _unwrap(Object? payload) {
  final envelope = _map(payload);
  if (envelope?['success'] == true && envelope!.containsKey('data')) {
    return envelope['data'];
  }
  return payload;
}

String _normalizeRole(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll('-', '_')
      .replaceAll(' ', '_');
  if (normalized.contains('audit')) return 'audit';
  if (normalized.contains('manager') ||
      normalized.contains('branch_head') ||
      normalized.contains('head_of_department')) {
    return 'manager';
  }
  if (normalized.contains('ceo') ||
      normalized.contains('owner') ||
      normalized.contains('admin') ||
      normalized.contains('director')) {
    return 'ceo';
  }
  if (normalized == 'parent' ||
      normalized == 'guardian' ||
      normalized == 'caregiver') {
    return 'parent';
  }
  return normalized;
}

String? _findRole(Object? value, [int depth = 0]) {
  if (depth > 6) return null;
  final map = _map(value);
  if (map != null) {
    final principalKind = _scalar(map['principal_kind']);
    if (_normalizeRole(principalKind ?? '') == 'student') return principalKind;
    for (final key in const [
      'role_code',
      'role_slug',
      'role_name',
      'account_type_slug',
      'account_type_name',
    ]) {
      final direct = _scalar(map[key]);
      if (direct != null) return direct;
    }
    final role = map['role'];
    final directRole = _scalar(role);
    if (directRole != null) return directRole;
    final roleMap = _map(role);
    if (roleMap != null) {
      for (final key in const ['code', 'slug', 'name']) {
        final nestedRole = _scalar(roleMap[key]);
        if (nestedRole != null) return nestedRole;
      }
    }
    for (final key in const [
      'profile',
      'user',
      'account',
      'roles',
      'role_memberships',
    ]) {
      final nestedRole = _findRole(map[key], depth + 1);
      if (nestedRole != null) return nestedRole;
    }
  } else if (value is Iterable && value is! String) {
    for (final child in value) {
      final nestedRole = _findRole(child, depth + 1);
      if (nestedRole != null) return nestedRole;
    }
  }
  return null;
}

const _roleReads = <String, List<String>>{
  'ceo': <String>[
    '/api/v1/org/branches/?page=1&page_size=1',
    '/api/v1/cohorts/?page=1&page_size=1',
    '/api/v1/payments/?page=1&page_size=1',
    '/api/v1/audit/?page_size=1',
    '/api/v1/reports/?page=1&page_size=1',
    '/api/v1/intelligence/branches/?page=1&page_size=1',
  ],
  'manager': <String>[
    '/api/v1/students/?page=1&page_size=1',
    '/api/v1/teachers/?page=1&page_size=1',
    '/api/v1/cohorts/?page=1&page_size=1',
    '/api/v1/payments/?page=1&page_size=1',
    '/api/v1/finance/invoices/?page=1&page_size=1',
  ],
  'audit': <String>[
    '/api/v1/audit/?page_size=1',
    '/api/v1/audit/export/',
    '/api/v1/approvals/ledger/?page=1&page_size=1',
    '/api/v1/intelligence/rules/',
  ],
  'student': <String>[
    '/api/v1/students/me/dashboard/',
    '/api/v1/students/me/report/',
    '/api/v1/users/me/',
  ],
  'parent': <String>['/api/v1/parents/me/children/', '/api/v1/users/me/'],
};

Future<void> main() async {
  final baseUrl = _requiredEnvironment('STARFORGE_API_BASE_URL');
  final username = _requiredEnvironment('STARFORGE_API_USERNAME');
  final password = _requiredEnvironment('STARFORGE_API_PASSWORD');
  final expectedRole = _normalizeRole(
    Platform.environment['STARFORGE_EXPECTED_ROLE'] ?? '',
  );
  final host = Platform.environment['STARFORGE_API_HOST'];
  final intervalMilliseconds =
      int.tryParse(Platform.environment['STARFORGE_PROBE_INTERVAL_MS'] ?? '') ??
      1000;
  final baseUri = Uri.tryParse(baseUrl);
  if (baseUri == null || !baseUri.hasScheme || !baseUri.hasAuthority) {
    stderr.writeln('STARFORGE_API_BASE_URL must be an absolute HTTP(S) URL.');
    exit(64);
  }
  if (baseUri.scheme != 'http' && baseUri.scheme != 'https') {
    stderr.writeln('STARFORGE_API_BASE_URL must use HTTP or HTTPS.');
    exit(64);
  }

  final probe = LiveProbe(
    baseUri: baseUri,
    hostHeader: host,
    minimumInterval: Duration(
      milliseconds: intervalMilliseconds.clamp(250, 30000),
    ),
  );
  final failures = <String>[];
  final checks = <String>[];

  const loginPaths = <String>[
    '/api/v1/auth/role-login/',
    '/api/v1/auth/login/',
    '/api/v1/auth/role-login',
    '/api/v1/auth/login',
  ];
  late ProbeResponse login;
  for (var index = 0; index < loginPaths.length; index++) {
    login = await probe.request(
      'POST',
      loginPaths[index],
      body: {'username': username, 'password': password},
      authenticate: false,
    );
    final routeIsMissing = login.status == 404 || login.status == 405;
    if (!routeIsMissing || index == loginPaths.length - 1) break;
  }
  if (!login.succeeded) {
    stderr.writeln(
      'Login failed (${login.status}, ${login.requestId}): ${_errorText(login)}',
    );
    exit(1);
  }
  final loginData = _unwrap(login.payload);
  final loginMap = _map(loginData);
  final token =
      _scalar(loginData) ??
      _findValue(loginData, const {
        'access',
        'access_token',
        'token',
        'session_key',
        'key',
      }) ??
      _scalar(loginMap?['session']) ??
      _scalar(loginMap?['key']);
  if (token == null) {
    stderr.writeln(
      'Login succeeded but no bearer session key was returned (${login.requestId}).',
    );
    exit(1);
  }
  probe.token = token;
  checks.add('login ${login.status}');

  final me = await probe.request('GET', '/api/v1/users/me/');
  if (!me.succeeded) {
    failures.add(
      '/users/me/ failed (${me.status}, ${me.requestId}): ${_errorText(me)}',
    );
  }
  final profile = _unwrap(me.payload);
  final publishedRole = _normalizeRole(_findRole(profile) ?? '');
  final role = expectedRole.isNotEmpty ? expectedRole : publishedRole;
  if (role.isEmpty || !_roleReads.containsKey(role)) {
    failures.add(
      'Unable to map the server profile to ceo, manager, audit, student or parent.',
    );
  } else {
    checks.add('profile role ${publishedRole.isEmpty ? role : publishedRole}');
    if (expectedRole.isNotEmpty &&
        publishedRole.isNotEmpty &&
        publishedRole != expectedRole) {
      failures.add(
        'Expected role $expectedRole, server returned $publishedRole.',
      );
    }
    for (final path in _roleReads[role]!) {
      final response = await probe.request('GET', path);
      if (!response.succeeded) {
        failures.add(
          '$role GET $path failed (${response.status}, ${response.requestId}): ${_errorText(response)}',
        );
        if (response.status == 429) break;
      } else {
        checks.add('$role GET ${path.split('?').first} ${response.status}');
      }
    }
  }

  if (!failures.any((failure) => failure.contains('(429,'))) {
    final missing = await probe.request('GET', '/api/v1/__workflow_missing__/');
    if (missing.status != 404) {
      failures.add('Unknown route returned ${missing.status}; expected 404.');
    } else {
      checks.add('not-found boundary 404');
    }
  }

  final logout = await probe.request(
    'POST',
    '/api/v1/auth/logout/',
    body: const <String, Object?>{},
  );
  if (!logout.succeeded) {
    failures.add(
      'Logout failed (${logout.status}, ${logout.requestId}): ${_errorText(logout)}',
    );
  } else {
    checks.add('logout ${logout.status}');
  }
  probe.token = null;

  stdout.writeln('Live API workflow checks (${checks.length}):');
  for (final check in checks) {
    stdout.writeln('- PASS $check');
  }
  if (failures.isNotEmpty) {
    stderr.writeln('Live API workflow failures (${failures.length}):');
    for (final failure in failures) {
      stderr.writeln('- FAIL $failure');
    }
    exit(1);
  }
}
