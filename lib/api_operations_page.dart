import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api_catalog.dart';
import 'api_client.dart';
import 'api_data_view.dart';
import 'data.dart';
import 'reference_ui.dart';
import 'theme.dart';

/// Advanced, role-aware access to every operation published in schema.json.
///
/// Normal workflows keep their purpose-built screens. This page is the
/// completeness and support layer for operations that do not yet deserve a
/// dedicated product surface.
class LiveApiOperationsPage extends StatefulWidget {
  const LiveApiOperationsPage({super.key, required this.role});

  final SfRole role;

  @override
  State<LiveApiOperationsPage> createState() => _LiveApiOperationsPageState();
}

class _LiveApiOperationsPageState extends State<LiveApiOperationsPage> {
  final _search = TextEditingController();
  String _query = '';
  String? _tag;
  String? _method;
  String? _runningOperation;
  String? _error;

  static const _auditTags = <String>{
    'audit',
    'intelligence',
    'finance',
    'payments',
    'ai',
    'cards',
    'forms',
    'messaging',
    'notifications',
    'reports',
    'rulebook',
    'tasks',
    'users',
  };

  static const _managerHiddenTags = <String>{'access', 'audit', 'intelligence'};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _permissionAllows(ApiSession session, ApiOperationSpec operation) {
    final grants = session.grantedPermissions;
    // Diagnostics must fail closed. It used to expose every operation when an
    // older /users/me response omitted grants, so read-only users only learned
    // about the restriction after producing a stream of 403 responses.
    if (grants.isEmpty) return false;
    return session.hasPermission(operation.permissionCode);
  }

  bool _roleAllows(ApiSession session, ApiOperationSpec operation) {
    // Authentication lifecycle has its own purpose-built UI. It is not mixed
    // into an authenticated administrative command centre.
    if (operation.tag == 'auth') return false;
    if (widget.role == SfRole.manager &&
        _managerHiddenTags.contains(operation.tag)) {
      return false;
    }
    if (widget.role == SfRole.audit &&
        (!operation.isReadOnly || !_auditTags.contains(operation.tag))) {
      return false;
    }
    return _permissionAllows(session, operation);
  }

  List<ApiOperationSpec> _available(ApiSession session) =>
      kPublishedApiOperations
          .where((operation) => _roleAllows(session, operation))
          .toList(growable: false);

  List<ApiOperationSpec> _filtered(ApiSession session) {
    final query = _query.trim().toLowerCase();
    return _available(session)
        .where((operation) {
          if (_tag != null && operation.tag != _tag) return false;
          if (_method != null && operation.method != _method) return false;
          if (query.isEmpty) return true;
          return operation.operationId.toLowerCase().contains(query) ||
              operation.summary.toLowerCase().contains(query) ||
              operation.path.toLowerCase().contains(query) ||
              operation.tag.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  Future<void> _openOperation(ApiOperationSpec operation) async {
    if (_runningOperation != null) return;
    final request = await showModalBottomSheet<_ApiOperationRequest>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SfTheme.of(context).surface,
      builder: (context) => _OperationRequestSheet(operation: operation),
    );
    if (request == null || !mounted) return;
    if (operation.isDestructive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Подтвердить удаление?'),
          content: Text(
            '${operation.method} ${request.resolvedPath}\n\n'
            'Серверное действие может быть необратимым.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Выполнить'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _runningOperation = operation.key;
      _error = null;
    });
    try {
      final result = await ApiScope.of(context).executePublishedOperation(
        operation,
        pathParameters: request.pathParameters,
        query: request.query,
        body: request.body,
      );
      if (!mounted) return;
      await _showResult(operation, request.resolvedPath, result);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = _apiError(error));
    } on ArgumentError catch (error) {
      if (mounted) {
        setState(() => _error = error.message?.toString() ?? '$error');
      }
    } finally {
      if (mounted) setState(() => _runningOperation = null);
    }
  }

  String _apiError(ApiException error) {
    final request = error.requestId.isEmpty ? '' : ' · ${error.requestId}';
    final status = error.status == 0 ? '' : '${error.status} · ';
    return '$status${error.message}$request';
  }

  String _prettyResult(Object? result) {
    if (result == null) return 'Команда выполнена. Сервер не вернул тело.';
    try {
      return const JsonEncoder.withIndent('  ').convert(result);
    } on JsonUnsupportedObjectError {
      return '$result';
    }
  }

  Future<void> _showResult(
    ApiOperationSpec operation,
    String path,
    Object? result,
  ) async {
    final text = _prettyResult(result);
    final colors = SfTheme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SfTheme(
        colors: colors,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              18,
              18,
              18 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${operation.method} выполнен',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                SelectableText(path),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: SingleChildScrollView(
                    child: ApiDataCard(
                      title: 'Ответ сервера',
                      value: result,
                      icon: Icons.cloud_done_rounded,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Копировать технический ответ'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final session = ApiScope.of(context);
    final available = _available(session);
    final operations = _filtered(session);
    final tags = available.map((item) => item.tag).toSet().toList()..sort();
    final methods = available.map((item) => item.method).toSet().toList()
      ..sort();

    return Scaffold(
      key: const ValueKey('live-api-operations'),
      backgroundColor: c.bg,
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: RefLargeHeader(
              eyebrow: 'OPENAPI · ${widget.role.name.toUpperCase()}',
              title: 'API-инструменты',
              subtitle:
                  '${available.length} разрешённых операций из '
                  '${kPublishedApiOperations.length} опубликованных · '
                  'роли настраиваются в разделе «Роли и доступ»',
              actions: [
                RefIconAction(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Обновить экран',
                  onPressed: () => setState(() {}),
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const ValueKey('api-operation-search'),
                    controller: _search,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: 'Поиск endpoint, команды или раздела',
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Все разделы'),
                          selected: _tag == null,
                          onSelected: (_) => setState(() => _tag = null),
                        ),
                        for (final tag in tags) ...[
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: Text(tag),
                            selected: _tag == tag,
                            onSelected: (_) => setState(() => _tag = tag),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: const Text('Все методы'),
                        selected: _method == null,
                        onSelected: (_) => setState(() => _method = null),
                      ),
                      for (final method in methods)
                        ChoiceChip(
                          label: Text(method),
                          selected: _method == method,
                          onSelected: (_) => setState(() => _method = method),
                        ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    MaterialBanner(
                      content: Text(_error!),
                      actions: [
                        TextButton(
                          onPressed: () => setState(() => _error = null),
                          child: const Text('Закрыть'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (operations.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('Операции не найдены')),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList.builder(
                itemCount: operations.length,
                itemBuilder: (context, index) {
                  final operation = operations[index];
                  final running = _runningOperation == operation.key;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _OperationTile(
                      operation: operation,
                      running: running,
                      onTap: () => _openOperation(operation),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _OperationTile extends StatelessWidget {
  const _OperationTile({
    required this.operation,
    required this.running,
    required this.onTap,
  });

  final ApiOperationSpec operation;
  final bool running;
  final VoidCallback onTap;

  Color _methodColor(SfColors c) => switch (operation.method) {
    'GET' => c.success,
    'POST' => c.primary,
    'PUT' || 'PATCH' => c.warn,
    'DELETE' => c.danger,
    _ => c.muted,
  };

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final methodColor = _methodColor(c);
    return RefSurfaceCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        key: ValueKey('api-operation-${operation.key}'),
        borderRadius: RefRadius.card,
        onTap: running ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: methodColor.withValues(alpha: .12),
                  borderRadius: RefRadius.pill,
                ),
                child: Text(
                  operation.method,
                  style: TextStyle(
                    color: methodColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'JetBrainsMono',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      operation.summary,
                      style: TextStyle(
                        color: c.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      operation.path,
                      style: TextStyle(
                        color: c.muted,
                        fontSize: 11,
                        fontFamily: 'JetBrainsMono',
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${operation.tag} · ${operation.operationId}',
                      style: TextStyle(color: c.muted2, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              running
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.chevron_right_rounded, color: c.muted2),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApiOperationRequest {
  const _ApiOperationRequest({
    required this.pathParameters,
    required this.query,
    required this.body,
    required this.resolvedPath,
  });

  final Map<String, String> pathParameters;
  final Map<String, Object?> query;
  final Object? body;
  final String resolvedPath;
}

class _OperationRequestSheet extends StatefulWidget {
  const _OperationRequestSheet({required this.operation});

  final ApiOperationSpec operation;

  @override
  State<_OperationRequestSheet> createState() => _OperationRequestSheetState();
}

class _OperationRequestSheetState extends State<_OperationRequestSheet> {
  late final Map<String, TextEditingController> _pathControllers = {
    for (final parameter in widget.operation.pathParameters)
      parameter: TextEditingController(),
  };
  final _query = TextEditingController(text: '{}');
  final _body = TextEditingController(text: '{}');
  String? _error;

  @override
  void dispose() {
    for (final controller in _pathControllers.values) {
      controller.dispose();
    }
    _query.dispose();
    _body.dispose();
    super.dispose();
  }

  Map<String, Object?> _object(String source, String label) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) throw FormatException('$label должен быть объектом');
    return Map<String, Object?>.from(decoded);
  }

  void _submit() {
    try {
      final pathParameters = <String, String>{};
      var resolvedPath = widget.operation.path;
      for (final entry in _pathControllers.entries) {
        final value = entry.value.text.trim();
        if (value.isEmpty) {
          throw FormatException('Заполните параметр ${entry.key}');
        }
        pathParameters[entry.key] = value;
        resolvedPath = resolvedPath.replaceAll(
          '{${entry.key}}',
          Uri.encodeComponent(value),
        );
      }
      final query = _object(_query.text, 'Query');
      final body = widget.operation.acceptsBody
          ? _object(_body.text, 'JSON-тело')
          : null;
      Navigator.of(context).pop(
        _ApiOperationRequest(
          pathParameters: pathParameters,
          query: query,
          body: body,
          resolvedPath: resolvedPath,
        ),
      );
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          18,
          18,
          18 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.operation.summary,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 5),
              SelectableText(
                '${widget.operation.method} ${widget.operation.path}',
                style: const TextStyle(fontFamily: 'JetBrainsMono'),
              ),
              for (final entry in _pathControllers.entries) ...[
                const SizedBox(height: 12),
                TextField(
                  key: ValueKey(
                    'api-operation-${widget.operation.operationId}-${entry.key}',
                  ),
                  controller: entry.value,
                  decoration: InputDecoration(labelText: 'Path · ${entry.key}'),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                key: ValueKey(
                  'api-operation-${widget.operation.operationId}-query',
                ),
                controller: _query,
                minLines: 2,
                maxLines: 6,
                style: const TextStyle(fontFamily: 'JetBrainsMono'),
                decoration: InputDecoration(
                  labelText: widget.operation.queryParameters.isEmpty
                      ? 'Query JSON · необязательно'
                      : 'Query JSON · '
                            '${widget.operation.queryParameters.join(', ')}',
                ),
              ),
              if (widget.operation.acceptsBody) ...[
                const SizedBox(height: 12),
                TextField(
                  key: ValueKey(
                    'api-operation-${widget.operation.operationId}-body',
                  ),
                  controller: _body,
                  minLines: 5,
                  maxLines: 12,
                  style: const TextStyle(fontFamily: 'JetBrainsMono'),
                  decoration: const InputDecoration(labelText: 'JSON-тело'),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 14),
              FilledButton.icon(
                key: ValueKey(
                  'api-operation-${widget.operation.operationId}-submit',
                ),
                onPressed: _submit,
                icon: const Icon(Icons.send_rounded),
                label: const Text('Выполнить через API'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
