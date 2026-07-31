import 'dart:convert';
import 'dart:io';

const _methods = <String>{'get', 'post', 'put', 'patch', 'delete'};

Never _usage() {
  stderr.writeln(
    'Usage: dart run tool/generate_api_catalog.dart '
    '<schema.json> [lib/api_catalog.g.dart]',
  );
  exit(64);
}

String _literal(Object? value) => jsonEncode(value);

List<String> _parameterNames(Iterable<dynamic> parameters, String location) {
  final names = <String>{};
  for (final item in parameters) {
    if (item is! Map || item['in'] != location) continue;
    final name = '${item['name'] ?? ''}'.trim();
    if (name.isNotEmpty) names.add(name);
  }
  final result = names.toList()..sort();
  return result;
}

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty || arguments.length > 2) _usage();
  final schemaFile = File(arguments[0]);
  if (!schemaFile.existsSync()) {
    stderr.writeln('Schema not found: ${schemaFile.path}');
    exit(66);
  }
  final outputFile = File(
    arguments.length == 2 ? arguments[1] : 'lib/api_catalog.g.dart',
  );
  final decoded = jsonDecode(await schemaFile.readAsString());
  if (decoded is! Map || decoded['paths'] is! Map) {
    stderr.writeln('OpenAPI schema does not contain a paths object.');
    exit(65);
  }

  final operations = <Map<String, Object?>>[];
  final paths = Map<String, dynamic>.from(decoded['paths'] as Map);
  final sortedPaths = paths.keys.toList()..sort();
  for (final path in sortedPaths) {
    final pathItem = paths[path];
    if (pathItem is! Map) continue;
    final sharedParameters = pathItem['parameters'] is List
        ? List<dynamic>.from(pathItem['parameters'] as List)
        : const <dynamic>[];
    for (final method in const ['get', 'post', 'put', 'patch', 'delete']) {
      if (!_methods.contains(method)) continue;
      final operation = pathItem[method];
      if (operation is! Map) continue;
      final operationParameters = operation['parameters'] is List
          ? List<dynamic>.from(operation['parameters'] as List)
          : const <dynamic>[];
      final parameters = [...sharedParameters, ...operationParameters];
      final operationId = '${operation['operationId'] ?? '${method}_$path'}'
          .trim();
      final tags = operation['tags'];
      final tag = tags is List && tags.isNotEmpty
          ? '${tags.first}'.trim()
          : 'system';
      operations.add({
        'operationId': operationId,
        'method': method.toUpperCase(),
        'path': path,
        'tag': tag.isEmpty ? 'system' : tag,
        'summary': '${operation['summary'] ?? operationId}'.trim(),
        'pathParameters': _parameterNames(parameters, 'path'),
        'queryParameters': _parameterNames(parameters, 'query'),
        'acceptsBody': operation['requestBody'] is Map,
        'requiresAuthentication':
            operation['security'] is List &&
            (operation['security'] as List).isNotEmpty,
      });
    }
  }

  final buffer = StringBuffer()
    ..writeln('// GENERATED FILE — DO NOT EDIT BY HAND.')
    ..writeln('// Source: ${schemaFile.path}')
    ..writeln('// Operations: ${operations.length}')
    ..writeln()
    ..writeln("part of 'api_catalog.dart';")
    ..writeln()
    ..writeln(
      'const List<ApiOperationSpec> kPublishedApiOperations = '
      '<ApiOperationSpec>[',
    );
  for (final operation in operations) {
    final pathParameters = operation['pathParameters']! as List<String>;
    final queryParameters = operation['queryParameters']! as List<String>;
    buffer
      ..writeln('  ApiOperationSpec(')
      ..writeln('    operationId: ${_literal(operation['operationId'])},')
      ..writeln('    method: ${_literal(operation['method'])},')
      ..writeln('    path: ${_literal(operation['path'])},')
      ..writeln('    tag: ${_literal(operation['tag'])},')
      ..writeln('    summary: ${_literal(operation['summary'])},');
    if (pathParameters.isNotEmpty) {
      buffer.writeln(
        '    pathParameters: <String>${_literal(pathParameters)},',
      );
    }
    if (queryParameters.isNotEmpty) {
      buffer.writeln(
        '    queryParameters: <String>${_literal(queryParameters)},',
      );
    }
    if (operation['acceptsBody'] == true) {
      buffer.writeln('    acceptsBody: true,');
    }
    if (operation['requiresAuthentication'] == false) {
      buffer.writeln('    requiresAuthentication: false,');
    }
    buffer.writeln('  ),');
  }
  buffer.writeln('];');

  await outputFile.parent.create(recursive: true);
  await outputFile.writeAsString(buffer.toString());
  stdout.writeln(
    'Generated ${operations.length} operations in ${outputFile.path}',
  );
}
