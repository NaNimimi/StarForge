part 'api_catalog.g.dart';

/// Immutable operation metadata generated from the supplied OpenAPI schema.
///
/// Normal product screens use typed resource helpers. This catalogue is the
/// completeness layer: it keeps every published operation reachable without
/// inventing paths that are absent from the backend contract.
class ApiOperationSpec {
  const ApiOperationSpec({
    required this.operationId,
    required this.method,
    required this.path,
    required this.tag,
    required this.summary,
    this.pathParameters = const <String>[],
    this.queryParameters = const <String>[],
    this.acceptsBody = false,
    this.requiresAuthentication = true,
  });

  final String operationId;
  final String method;
  final String path;
  final String tag;
  final String summary;
  final List<String> pathParameters;
  final List<String> queryParameters;
  final bool acceptsBody;
  final bool requiresAuthentication;

  bool get isReadOnly => method == 'GET';
  bool get isDestructive => method == 'DELETE';
  String get key => '$method:$path';
  String get permissionCode => '$tag:${isReadOnly ? 'read' : 'write'}';
}
