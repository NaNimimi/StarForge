import 'dart:convert';
import 'dart:io';

const _httpMethods = <String>{'get', 'post', 'put', 'patch', 'delete'};
const _requiredErrorStatuses = <String>{'400', '401', '403', '404', '429'};

Map<String, dynamic>? _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

List<dynamic> _list(Object? value) =>
    value is List ? List<dynamic>.from(value) : const <dynamic>[];

Never _usage() {
  stderr.writeln(
    'Usage: dart tool/openapi_workflow_audit.dart '
    '<schema.json> [lib/api_catalog.g.dart]',
  );
  exit(64);
}

void _require(bool condition, String message, List<String> failures) {
  if (!condition) failures.add(message);
}

Set<String> _requiredFields(Map<String, dynamic>? schema) =>
    _list(schema?['required']).map((value) => '$value').toSet();

Future<void> _writeSummary(List<String> lines) async {
  final path = Platform.environment['GITHUB_STEP_SUMMARY'];
  if (path == null || path.trim().isEmpty) return;
  await File(
    path,
  ).writeAsString('${lines.join('\n')}\n', mode: FileMode.append, flush: true);
}

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty || arguments.length > 2) _usage();

  final schemaFile = File(arguments.first);
  final catalogFile = File(
    arguments.length == 2 ? arguments[1] : 'lib/api_catalog.g.dart',
  );
  if (!schemaFile.existsSync()) {
    stderr.writeln('OpenAPI schema not found: ${schemaFile.path}');
    exit(66);
  }
  if (!catalogFile.existsSync()) {
    stderr.writeln('Generated API catalogue not found: ${catalogFile.path}');
    exit(66);
  }

  Object? decoded;
  try {
    decoded = jsonDecode(await schemaFile.readAsString());
  } on FormatException catch (error) {
    stderr.writeln('OpenAPI schema is not valid JSON: $error');
    exit(65);
  }
  final root = _map(decoded);
  final paths = _map(root?['paths']);
  final components = _map(root?['components']);
  final schemas = _map(components?['schemas']);
  final failures = <String>[];

  _require(root != null, 'The document root must be a JSON object.', failures);
  _require(
    '${root?['openapi'] ?? ''}'.startsWith('3.'),
    'Only OpenAPI 3.x is supported.',
    failures,
  );
  _require(
    paths != null,
    'The document must publish a paths object.',
    failures,
  );

  final operations = <String, ({String id, String tag})>{};
  final operationIds = <String>{};
  final duplicateIds = <String>{};
  final methodCounts = <String, int>{};
  var publicOperations = 0;
  var protectedOperations = 0;
  var genericObjectBodies = 0;

  for (final pathEntry in (paths ?? const <String, dynamic>{}).entries) {
    final path = pathEntry.key;
    final pathItem = _map(pathEntry.value);
    if (pathItem == null) continue;
    for (final method in _httpMethods) {
      final operation = _map(pathItem[method]);
      if (operation == null) continue;
      final operationId = '${operation['operationId'] ?? ''}'.trim();
      final tagValues = _list(operation['tags']);
      final tag = tagValues.isEmpty ? 'system' : '${tagValues.first}'.trim();
      final key = '${method.toUpperCase()}:$path';
      methodCounts.update(
        method.toUpperCase(),
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      _require(operationId.isNotEmpty, '$key has no operationId.', failures);
      if (operationId.isNotEmpty && !operationIds.add(operationId)) {
        duplicateIds.add(operationId);
      }
      operations[key] = (id: operationId, tag: tag);

      final security = _list(operation['security']);
      if (security.isEmpty) {
        publicOperations++;
      } else {
        protectedOperations++;
        final hasSessionAuth = security.any((item) {
          final declaration = _map(item);
          return declaration?.containsKey('sessionAuth') == true;
        });
        _require(
          hasSessionAuth,
          '$key does not declare sessionAuth.',
          failures,
        );
      }

      final responses = _map(operation['responses']) ?? const {};
      for (final status in _requiredErrorStatuses) {
        _require(
          responses.containsKey(status),
          '$key does not document HTTP $status.',
          failures,
        );
      }
      _require(
        responses.keys.any((status) => status.startsWith('2')),
        '$key does not document a success response.',
        failures,
      );

      final requestBody = _map(operation['requestBody']);
      final content = _map(requestBody?['content']);
      final jsonContent = _map(content?['application/json']);
      final bodySchema = _map(jsonContent?['schema']);
      if (bodySchema?['type'] == 'object' &&
          !bodySchema!.containsKey(r'$ref') &&
          (_map(bodySchema['properties'])?.isEmpty ?? true)) {
        genericObjectBodies++;
      }
    }
  }

  _require(
    operations.length == 487,
    'Expected 487 operations, found ${operations.length}.',
    failures,
  );
  _require(
    paths?.length == 321,
    'Expected 321 paths, found ${paths?.length ?? 0}.',
    failures,
  );
  _require(
    publicOperations == 3,
    'Expected 3 public operations, found $publicOperations.',
    failures,
  );
  _require(
    protectedOperations == 484,
    'Expected 484 protected operations, found $protectedOperations.',
    failures,
  );

  final securitySchemes = _map(components?['securitySchemes']);
  final sessionAuth = _map(securitySchemes?['sessionAuth']);
  _require(
    sessionAuth?['type'] == 'http',
    'sessionAuth must be an HTTP scheme.',
    failures,
  );
  _require(
    sessionAuth?['scheme'] == 'bearer',
    'sessionAuth must use bearer authentication.',
    failures,
  );

  final success = _map(schemas?['Success']);
  final successProperties = _map(success?['properties']);
  _require(
    _requiredFields(success).contains('success'),
    'Success.success must be required.',
    failures,
  );
  for (final field in const ['success', 'data', 'pagination', 'warnings']) {
    _require(
      successProperties?.containsKey(field) == true,
      'Success.$field is missing.',
      failures,
    );
  }

  final error = _map(schemas?['Error']);
  final errorRequired = _requiredFields(error);
  _require(
    errorRequired.containsAll(const {'success', 'code', 'message'}),
    'Error must require success, code and message.',
    failures,
  );
  _require(
    _map(error?['properties'])?.containsKey('errors') == true,
    'Error.errors is missing.',
    failures,
  );

  final pagination = _map(schemas?['Pagination']);
  final paginationProperties = _map(pagination?['properties']);
  for (final field in const [
    'total',
    'page',
    'page_size',
    'pages',
    'has_next',
    'has_prev',
  ]) {
    _require(
      paginationProperties?.containsKey(field) == true,
      'Pagination.$field is missing.',
      failures,
    );
  }

  final catalogText = await catalogFile.readAsString();
  final catalogPattern = RegExp(
    r'ApiOperationSpec\(\s*operationId:\s*"([^"]+)",\s*method:\s*"([^"]+)",\s*path:\s*"([^"]+)"',
    multiLine: true,
  );
  final catalogOperations = <String, String>{};
  for (final match in catalogPattern.allMatches(catalogText)) {
    final id = match.group(1)!;
    final method = match.group(2)!;
    final path = match.group(3)!;
    catalogOperations['$method:$path'] = id;
  }
  _require(
    catalogOperations.length == operations.length,
    'Generated catalogue has ${catalogOperations.length} operations; schema has ${operations.length}.',
    failures,
  );
  for (final entry in operations.entries) {
    final catalogId = catalogOperations[entry.key];
    _require(
      catalogId == entry.value.id,
      'Catalogue mismatch for ${entry.key}: expected ${entry.value.id}, found ${catalogId ?? 'missing'}.',
      failures,
    );
  }
  for (final key in catalogOperations.keys) {
    _require(
      operations.containsKey(key),
      'Catalogue contains unpublished operation $key.',
      failures,
    );
  }

  final sortedCounts = methodCounts.entries.toList()
    ..sort((left, right) => left.key.compareTo(right.key));
  final summary = <String>[
    '## StarForge OpenAPI contract',
    '',
    failures.isEmpty ? '✅ Contract audit passed.' : '❌ Contract audit failed.',
    '',
    '- Paths: ${paths?.length ?? 0}',
    '- Operations: ${operations.length}',
    '- Methods: ${sortedCounts.map((entry) => '${entry.key} ${entry.value}').join(', ')}',
    '- Protected/public: $protectedOperations/$publicOperations',
    '- Generic pass-through request bodies: $genericObjectBodies',
    '- Generated catalogue entries: ${catalogOperations.length}',
    if (duplicateIds.isNotEmpty)
      '- Upstream duplicate operation IDs (METHOD + PATH fallback is used): '
          '${duplicateIds.join(', ')}',
  ];
  await _writeSummary(summary);

  stdout.writeln(summary.skip(2).join('\n'));
  if (failures.isNotEmpty) {
    stderr.writeln('\nContract failures (${failures.length}):');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exit(1);
  }
  if (duplicateIds.isNotEmpty) {
    stdout.writeln('\nSchema warnings:');
    stdout.writeln(
      '- Duplicate upstream operationId values: ${duplicateIds.join(', ')}.',
    );
  }
}
