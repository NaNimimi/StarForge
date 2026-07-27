import 'package:flutter/material.dart';

import 'api_client.dart';
import 'reference_ui.dart';
import 'settings.dart';
import 'theme.dart';

/// The mobile equivalent of the web Settings → API connection card.
///
/// It performs a real tenant login and live data warm-up. No password or token
/// is persisted to source code or shown in the UI after authentication.
class ApiConnectionScreen extends StatefulWidget {
  const ApiConnectionScreen({super.key});

  @override
  State<ApiConnectionScreen> createState() => _ApiConnectionScreenState();
}

class _ApiConnectionScreenState extends State<ApiConnectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _endpoint = TextEditingController(
    text: 'https://starforge.78.111.91.113.nip.io',
  );
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _endpoint.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;
    final session = ApiScope.of(context);
    final settings = SettingsScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await session.login(
        endpoint: _endpoint.text,
        username: _username.text,
        password: _password.text,
        language: settings.lang.name,
      );
      _password.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: const Text('Connected to StarForge API'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: SfTheme.of(context).success,
          ),
        );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to connect to the API.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    setState(() => _busy = true);
    try {
      await ApiScope.of(context).logout();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _message(ApiException error) {
    final fields =
        error.errors?.entries
            .map((entry) => '${entry.key}: ${entry.value}')
            .join('\n') ??
        '';
    return [
      error.message,
      if (fields.isNotEmpty) fields,
      'Request ID: ${error.requestId}',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final session = ApiScope.of(context);
    final connected = session.authenticated;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: c.border)),
        title: Text(
          'Settings',
          style: RefType.ui(size: 16, weight: FontWeight.w800, color: c.ink),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
        children: [
          Text(
            'BACKEND CONNECTION',
            style: RefType.eyebrow(color: c.muted, size: 10.5),
          ),
          const SizedBox(height: 8),
          RefSurfaceCard(
            padding: const EdgeInsets.all(16),
            child: connected ? _connectedCard(c, session) : _connectionForm(c),
          ),
          const SizedBox(height: 18),
          Text('LIVE DATA', style: RefType.eyebrow(color: c.muted, size: 10.5)),
          const SizedBox(height: 8),
          RefSurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _dataRow(c, 'Students', session.records('students').length),
                _dataRow(c, 'Teachers', session.records('teachers').length),
                _dataRow(c, 'Groups', session.records('groups').length),
                _dataRow(
                  c,
                  'Payments',
                  session.records('payments').length,
                  last: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _connectedCard(SfColors c, ApiSession session) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: c.successSoft,
              borderRadius: const BorderRadius.all(Radius.circular(9)),
            ),
            child: Icon(Icons.check_rounded, size: 18, color: c.success),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connected',
                  style: RefType.ui(
                    size: 13.5,
                    weight: FontWeight.w800,
                    color: c.ink,
                  ),
                ),
                Text(
                  session.client.baseUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RefType.mono(size: 10, color: c.muted),
                ),
              ],
            ),
          ),
        ],
      ),
      if (session.me != null) ...[
        const SizedBox(height: 14),
        _detail(
          c,
          'Account',
          '${session.me?['full_name'] ?? session.me?['username'] ?? '—'}',
        ),
        _detail(
          c,
          'Role',
          '${session.me?['role'] ?? session.me?['role_name'] ?? '—'}',
        ),
      ],
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: RefButton(
              label: 'Refresh data',
              kind: RefButtonKind.soft,
              leading: Icons.refresh_rounded,
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      try {
                        await session.reloadAll();
                      } on ApiException catch (error) {
                        if (mounted) setState(() => _error = _message(error));
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
            ),
          ),
          const SizedBox(width: 8),
          RefButton(
            label: 'Disconnect',
            kind: RefButtonKind.ghost,
            onPressed: _busy ? null : _disconnect,
          ),
        ],
      ),
      if (_error != null) _errorBox(c),
    ],
  );

  Widget _connectionForm(SfColors c) => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Use your center tenant URL and staff account. The opaque session is kept only while the app is open.',
          style: RefType.ui(size: 12, color: c.muted, height: 1.45),
        ),
        const SizedBox(height: 16),
        _field(
          c,
          controller: _endpoint,
          label: 'Tenant API URL',
          hint: 'https://center.example.com',
          keyboard: TextInputType.url,
        ),
        const SizedBox(height: 12),
        _field(
          c,
          controller: _username,
          label: 'Username',
          hint: 'director',
          keyboard: TextInputType.text,
        ),
        const SizedBox(height: 12),
        _field(
          c,
          controller: _password,
          label: 'Password',
          hint: '••••••••',
          obscure: _hidePassword,
          suffix: IconButton(
            onPressed: () => setState(() => _hidePassword = !_hidePassword),
            icon: Icon(
              _hidePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: c.muted,
              size: 18,
            ),
          ),
        ),
        if (_error != null) _errorBox(c),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: RefButton(
            label: _busy ? 'Connecting…' : 'Connect API',
            kind: RefButtonKind.primary,
            leading: Icons.login_rounded,
            onPressed: _busy ? null : _connect,
          ),
        ),
      ],
    ),
  );

  Widget _field(
    SfColors c, {
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboard,
    bool obscure = false,
    Widget? suffix,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: RefType.eyebrow(color: c.muted, size: 9.5),
      ),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        keyboardType: keyboard,
        obscureText: obscure,
        autocorrect: false,
        enableSuggestions: !obscure,
        validator: (value) =>
            value == null || value.trim().isEmpty ? 'Required' : null,
        style: RefType.ui(size: 13, color: c.ink),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: RefType.ui(size: 13, color: c.muted),
          suffixIcon: suffix,
          filled: true,
          fillColor: c.surface2,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: c.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: c.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: c.danger),
          ),
        ),
      ),
    ],
  );

  Widget _errorBox(SfColors c) => Container(
    margin: const EdgeInsets.only(top: 14),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: c.dangerSoft,
      borderRadius: const BorderRadius.all(Radius.circular(9)),
    ),
    child: Text(
      _error!,
      style: RefType.ui(size: 11.5, color: c.danger, height: 1.35),
    ),
  );

  Widget _detail(SfColors c, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      children: [
        Text(label, style: RefType.ui(size: 11.5, color: c.muted)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: RefType.ui(
              size: 11.5,
              weight: FontWeight.w700,
              color: c.ink,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _dataRow(SfColors c, String label, int count, {bool last = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: c.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: RefType.ui(
                  size: 12.5,
                  weight: FontWeight.w600,
                  color: c.ink,
                ),
              ),
            ),
            Text(
              '$count',
              style: RefType.mono(
                size: 12,
                weight: FontWeight.w700,
                color: c.muted,
              ),
            ),
          ],
        ),
      );
}
