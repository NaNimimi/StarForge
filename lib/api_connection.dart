import 'dart:async';

import 'package:flutter/material.dart';

import 'api_client.dart';
import 'api_data_view.dart';
import 'i18n.dart';
import 'reference_ui.dart';
import 'settings.dart';
import 'theme.dart';
import 'widgets.dart';

/// Primary application sign-in. Authentication and role selection are both
/// server-authoritative: the app never lets a user promote themselves by
/// choosing a local workspace.
class ApiLoginScreen extends StatefulWidget {
  const ApiLoginScreen({super.key});

  @override
  State<ApiLoginScreen> createState() => _ApiLoginScreenState();
}

class _ApiLoginScreenState extends State<ApiLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;
  bool _busy = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  String? _error;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _startCooldown(Duration? retryAfter) {
    _cooldownTimer?.cancel();
    final serverSeconds = retryAfter?.inSeconds ?? 60;
    _cooldownSeconds = serverSeconds < 1 ? 60 : serverSeconds;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownSeconds--;
        if (_cooldownSeconds <= 0) {
          _cooldownSeconds = 0;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _submit() async {
    if (_busy || _cooldownSeconds > 0 || !_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final settings = SettingsScope.of(context);
    try {
      await ApiScope.of(context).login(
        endpoint: kDefaultApiBaseUrl,
        username: _username.text,
        password: _password.text,
        language: settings.lang.name,
      );
      _password.clear();
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = _apiLoginMessage(context, error));
        if (error.status == 429) _startCooldown(error.retryAfter);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = tx(
            context,
            uz: 'API bilan ulanish imkonsiz. Internetni tekshirib, qayta urinib ko‘ring.',
            ru: 'Не удалось подключиться к API. Проверьте интернет и попробуйте снова.',
            en: 'Unable to connect to the API. Check your connection and try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? tr(context, 'err_empty') : null;

  Future<void> _forgotPassword() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SfTheme.of(context).surface,
      builder: (context) => _PasswordResetSheet(
        endpoint: kDefaultApiBaseUrl,
        language: SettingsScope.of(context).lang.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    final settings = SettingsScope.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -90,
            child: Container(
              width: 310,
              height: 310,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    c.primary.withValues(alpha: .22),
                    c.primary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -110,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    c.accent.withValues(alpha: .18),
                    c.accent.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 470),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: c.primary,
                            borderRadius: RefRadius.lg,
                          ),
                          child: Center(
                            child: SfStar(size: 25, color: c.surface),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'StarForge EDU',
                                style: RefType.ui(
                                  size: 19,
                                  weight: FontWeight.w900,
                                  color: c.ink,
                                ),
                              ),
                              Text(
                                tr(context, 'brand_sub'),
                                style: RefType.ui(size: 11.5, color: c.muted),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<SfLang>(
                          tooltip: tr(context, 'set_lang'),
                          initialValue: settings.lang,
                          onSelected: settings.setLang,
                          itemBuilder: (_) => [
                            for (final lang in SfLang.values)
                              PopupMenuItem(
                                value: lang,
                                child: Text(langName(context, lang)),
                              ),
                          ],
                          child: RefPill(
                            label: settings.lang.name.toUpperCase(),
                            tone: RefPillTone.neutral,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 34),
                    RefSurfaceCard(
                      elevated: true,
                      padding: const EdgeInsets.all(20),
                      child: AutofillGroup(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                tr(context, 'login_title'),
                                style: RefType.display(size: 31, color: c.ink),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                tx(
                                  context,
                                  uz: 'Rol va ruxsatlar server hisobingizdan avtomatik olinadi.',
                                  ru: 'Роль и права будут автоматически получены из серверной учётной записи.',
                                  en: 'Your role and permissions are loaded automatically from the server account.',
                                ),
                                style: RefType.ui(
                                  size: 12.5,
                                  color: c.muted,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                key: const ValueKey('api-login-username'),
                                controller: _username,
                                autofillHints: const [AutofillHints.username],
                                textInputAction: TextInputAction.next,
                                autocorrect: false,
                                enableSuggestions: false,
                                validator: _required,
                                decoration: InputDecoration(
                                  labelText: tr(context, 'login_hint'),
                                  prefixIcon: const Icon(
                                    Icons.person_outline_rounded,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                key: const ValueKey('api-login-password'),
                                controller: _password,
                                autofillHints: const [AutofillHints.password],
                                textInputAction: TextInputAction.done,
                                obscureText: _hidePassword,
                                validator: _required,
                                onFieldSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: tr(context, 'pass_hint'),
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    tooltip: _hidePassword
                                        ? tx(
                                            context,
                                            uz: 'Parolni ko‘rsatish',
                                            ru: 'Показать пароль',
                                            en: 'Show password',
                                          )
                                        : tx(
                                            context,
                                            uz: 'Parolni yashirish',
                                            ru: 'Скрыть пароль',
                                            en: 'Hide password',
                                          ),
                                    onPressed: () => setState(
                                      () => _hidePassword = !_hidePassword,
                                    ),
                                    icon: Icon(
                                      _hidePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                _ApiErrorCard(message: _error!),
                              ],
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                key: const ValueKey('api-login-submit'),
                                onPressed: _busy || _cooldownSeconds > 0
                                    ? null
                                    : _submit,
                                icon: _busy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.login_rounded),
                                label: Text(
                                  _busy
                                      ? tx(
                                          context,
                                          uz: 'Ulanmoqda…',
                                          ru: 'Подключение…',
                                          en: 'Connecting…',
                                        )
                                      : _cooldownSeconds > 0
                                      ? tx(
                                          context,
                                          uz: 'Qayta urinish · ${_cooldownSeconds}s',
                                          ru: 'Повторить · $_cooldownSeconds сек.',
                                          en: 'Retry · ${_cooldownSeconds}s',
                                        )
                                      : tr(context, 'sign_in'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                key: const ValueKey(
                                  'api-login-forgot-password',
                                ),
                                onPressed: _busy ? null : _forgotPassword,
                                child: Text(
                                  tx(
                                    context,
                                    uz: 'Parolni unutdingizmi?',
                                    ru: 'Забыли пароль?',
                                    en: 'Forgot password?',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 15,
                          color: c.success,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            tx(
                              context,
                              uz: 'HTTPS · token faqat joriy sessiyada saqlanadi',
                              ru: 'HTTPS · токен хранится только в текущей сессии',
                              en: 'HTTPS · token is kept only for the current session',
                            ),
                            textAlign: TextAlign.center,
                            style: RefType.ui(size: 10.5, color: c.muted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _validationFieldLabel(BuildContext context, Object? raw) {
  final key = '${raw ?? ''}'.trim().toLowerCase();
  return switch (key) {
    'username' || 'login' => tr(context, 'login_hint'),
    'password' => tr(context, 'pass_hint'),
    'phone' ||
    'phone_number' => tx(context, uz: 'Telefon', ru: 'Телефон', en: 'Phone'),
    'code' || 'verification_code' => tx(
      context,
      uz: 'Tasdiqlash kodi',
      ru: 'Код подтверждения',
      en: 'Verification code',
    ),
    'new_password' => tx(
      context,
      uz: 'Yangi parol',
      ru: 'Новый пароль',
      en: 'New password',
    ),
    'current_password' => tx(
      context,
      uz: 'Joriy parol',
      ru: 'Текущий пароль',
      en: 'Current password',
    ),
    'non_field_errors' ||
    'detail' => tx(context, uz: 'Tafsilot', ru: 'Подробности', en: 'Details'),
    _ =>
      key
          .replaceAll('_', ' ')
          .split(' ')
          .where((part) => part.isNotEmpty)
          .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
          .join(' '),
  };
}

String _validationValue(BuildContext context, Object? raw) {
  if (raw == null) {
    return tx(
      context,
      uz: 'Qiymat ko‘rsatilmagan',
      ru: 'Значение не указано',
      en: 'No value provided',
    );
  }
  final value = '$raw'.trim();
  return switch (value.toLowerCase()) {
    'required' || 'this field is required.' => tx(
      context,
      uz: 'Majburiy maydon',
      ru: 'Обязательное поле',
      en: 'Required field',
    ),
    'blank' || 'this field may not be blank.' => tx(
      context,
      uz: 'Maydon bo‘sh bo‘lmasligi kerak',
      ru: 'Поле не должно быть пустым',
      en: 'The field cannot be blank',
    ),
    'null' || 'this field may not be null.' => tx(
      context,
      uz: 'Qiymat ko‘rsatilishi kerak',
      ru: 'Необходимо указать значение',
      en: 'A value is required',
    ),
    'invalid' || 'invalid value.' => tx(
      context,
      uz: 'Noto‘g‘ri qiymat',
      ru: 'Некорректное значение',
      en: 'Invalid value',
    ),
    _ =>
      value.isEmpty
          ? tx(
              context,
              uz: 'Noto‘g‘ri qiymat',
              ru: 'Некорректное значение',
              en: 'Invalid value',
            )
          : value,
  };
}

String _validationErrorsText(
  BuildContext context,
  Map<String, dynamic>? errors,
) {
  if (errors == null || errors.isEmpty) return '';
  final lines = <String>[];

  void visit(Object? raw, List<String> path, int depth) {
    if (depth > 6) return;
    final value = apiPresentationValue(raw);
    if (value is Map) {
      if (value.isEmpty) {
        lines.add(
          '${path.map((part) => _validationFieldLabel(context, part)).join(' · ')}: '
          '${_validationValue(context, null)}',
        );
        return;
      }
      for (final entry in value.entries) {
        visit(entry.value, [...path, '${entry.key}'], depth + 1);
      }
      return;
    }
    if (value is Iterable && value is! String) {
      if (value.isEmpty) {
        visit(null, path, depth + 1);
      } else {
        for (final item in value) {
          visit(item, path, depth + 1);
        }
      }
      return;
    }
    final label = path
        .map((part) => _validationFieldLabel(context, part))
        .join(' · ');
    lines.add('$label: ${_validationValue(context, value)}');
  }

  for (final entry in errors.entries) {
    visit(entry.value, [entry.key], 0);
  }
  return lines.toSet().join('\n');
}

String _apiExceptionText(BuildContext context, ApiException error) {
  final fields = _validationErrorsText(context, error.errors);
  final request = error.requestId.trim();
  return [
    error.message,
    if (fields.isNotEmpty) fields,
    if (request.isNotEmpty) 'Request ID: $request',
  ].join('\n');
}

String _apiLoginMessage(BuildContext context, ApiException error) {
  final request = '\nRequest ID: ${error.requestId}';
  if (error.status == 402 || error.code == 'subscription_required') {
    return '${tx(context, uz: 'Markaz obunasi to‘xtatilgan. Billing xizmatiga murojaat qiling.', ru: 'Подписка центра приостановлена. Обратитесь в billing.', en: 'The center subscription is suspended. Contact billing.')}$request';
  }
  if (error.status == 401 || error.code == 'invalid_credentials') {
    return '${tr(context, 'err_wrong')}$request';
  }
  if (error.status == 429) {
    return '${tx(context, uz: 'Juda ko‘p kirish urinishi. Biroz kutib, qayta urinib ko‘ring.', ru: 'Слишком много попыток входа. Немного подождите и попробуйте снова.', en: 'Too many sign-in attempts. Wait a moment and try again.')}$request';
  }
  if (error.code == 'validation_error' ||
      error.status == 400 ||
      error.status == 422) {
    final fields = _validationErrorsText(context, error.errors);
    final message = tx(
      context,
      uz: 'Kiritilgan ma’lumotlarni tekshiring.',
      ru: 'Проверьте введённые данные.',
      en: 'Check the entered data.',
    );
    return '$message${fields.isEmpty ? '' : '\n$fields'}'
        '$request';
  }
  if (error.status == 403) {
    return '${tx(context, uz: 'Bu hisob uchun kirish taqiqlangan.', ru: 'Вход для этой учётной записи запрещён.', en: 'Sign-in is not allowed for this account.')}$request';
  }
  if (error.status == 404) {
    return '${tx(context, uz: 'O‘quv markazi serverda topilmadi.', ru: 'Учебный центр не найден на сервере.', en: 'The education center was not found on the server.')}$request';
  }
  if (error.code == 'invalid_profile_response') {
    return '${tx(context, uz: 'Server hisob profilini noto‘g‘ri formatda qaytardi.', ru: 'Сервер вернул профиль аккаунта в неверном формате.', en: 'The server returned an invalid account profile.')}$request';
  }
  if (error.code == 'invalid_response') {
    return '${tx(context, uz: 'Serverdan noto‘g‘ri javob olindi.', ru: 'Получен некорректный ответ сервера.', en: 'The server returned an invalid response.')}$request';
  }
  if (error.code == 'login_client_error') {
    return '${tx(context, uz: 'Kirish vaqtida kutilmagan xatolik yuz berdi.', ru: 'Во время входа произошла непредвиденная ошибка.', en: 'An unexpected error occurred during sign-in.')}\n${error.message}$request';
  }
  if (error.isTimeout) {
    return '${tx(context, uz: 'Server javob bermadi. Internetni tekshiring.', ru: 'Сервер не ответил. Проверьте интернет.', en: 'The server did not respond. Check your connection.')}$request';
  }
  if (error.status == 0) {
    return '${tx(context, uz: 'API bilan ulanish imkonsiz. Internetni tekshiring.', ru: 'Не удалось подключиться к API. Проверьте интернет.', en: 'Unable to connect to the API. Check your connection.')}'
        '\n${error.message}$request';
  }
  return '${error.message}$request';
}

class _ApiErrorCard extends StatelessWidget {
  const _ApiErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = SfTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: c.dangerSoft,
        borderRadius: RefRadius.md,
        border: Border.all(color: c.danger.withValues(alpha: .25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: c.danger, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: RefType.ui(size: 11.5, color: c.danger, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

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
  final _endpoint = TextEditingController(text: kDefaultApiBaseUrl);
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

  Future<void> _showChangePassword() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SfTheme.of(context).surface,
      builder: (context) => const _ChangePasswordSheet(),
    );
  }

  String _message(ApiException error) {
    if (error.status == 402 || error.code == 'subscription_required') {
      return 'Подписка этого центра приостановлена. API доступен, но сервер '
          'блокирует вход до восстановления подписки у владельца backend.\n'
          'Request ID: ${error.requestId}';
    }
    return _apiExceptionText(context, error);
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
      SizedBox(
        width: double.infinity,
        child: RefButton(
          key: const ValueKey('api-change-password'),
          label: 'Сменить пароль аккаунта',
          kind: RefButtonKind.ghost,
          leading: Icons.password_rounded,
          onPressed: _busy ? null : _showChangePassword,
        ),
      ),
      const SizedBox(height: 8),
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

class _PasswordResetSheet extends StatefulWidget {
  const _PasswordResetSheet({required this.endpoint, required this.language});

  final String endpoint;
  final String language;

  @override
  State<_PasswordResetSheet> createState() => _PasswordResetSheetState();
}

class _PasswordResetSheetState extends State<_PasswordResetSheet> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _codeRequested = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (_phone.text.trim().isEmpty || _busy) {
      setState(() => _error = 'Введите телефон аккаунта');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiScope.of(context).requestPasswordReset(
        endpoint: widget.endpoint,
        phone: _phone.text,
        language: widget.language,
      );
      if (mounted) setState(() => _codeRequested = true);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = _apiExceptionText(context, error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmReset() async {
    if (_busy) return;
    if (_code.text.trim().isEmpty ||
        _password.text.isEmpty ||
        _password.text != _confirm.text) {
      setState(
        () => _error = _password.text != _confirm.text
            ? 'Пароли не совпадают'
            : 'Заполните код и новый пароль',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiScope.of(context).confirmPasswordReset(
        endpoint: widget.endpoint,
        phone: _phone.text,
        code: _code.text,
        newPassword: _password.text,
        language: widget.language,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пароль изменён. Теперь войдите снова.')),
      );
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = _apiExceptionText(context, error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
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
                'Восстановление пароля',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'Код подтверждения отправляет сервер StarForge. '
                'Приложение не хранит телефон, код или новый пароль.',
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('api-reset-phone'),
                controller: _phone,
                enabled: !_codeRequested && !_busy,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: const InputDecoration(
                  labelText: 'Телефон аккаунта',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              if (_codeRequested) ...[
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('api-reset-code'),
                  controller: _code,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  decoration: const InputDecoration(
                    labelText: 'Код подтверждения',
                    prefixIcon: Icon(Icons.pin_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('api-reset-password'),
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: const InputDecoration(
                    labelText: 'Новый пароль',
                    prefixIcon: Icon(Icons.password_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('api-reset-confirm'),
                  controller: _confirm,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Повторите пароль',
                    prefixIcon: Icon(Icons.password_rounded),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                _ApiErrorCard(message: _error!),
              ],
              const SizedBox(height: 14),
              FilledButton.icon(
                key: ValueKey(
                  _codeRequested
                      ? 'api-reset-confirm-submit'
                      : 'api-reset-request-submit',
                ),
                onPressed: _busy
                    ? null
                    : _codeRequested
                    ? _confirmReset
                    : _requestCode,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _codeRequested
                            ? Icons.check_rounded
                            : Icons.sms_outlined,
                      ),
                label: Text(
                  _codeRequested ? 'Изменить пароль' : 'Получить код',
                ),
              ),
              if (_codeRequested)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _codeRequested = false),
                  child: const Text('Изменить телефон'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_current.text.isEmpty ||
        _password.text.isEmpty ||
        _password.text != _confirm.text) {
      setState(
        () => _error = _password.text != _confirm.text
            ? 'Пароли не совпадают'
            : 'Заполните все поля',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiScope.of(context).changePassword(
        currentPassword: _current.text,
        newPassword: _password.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Пароль аккаунта изменён')));
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = _apiExceptionText(context, error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
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
                'Сменить пароль',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('api-change-current'),
                controller: _current,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(labelText: 'Текущий пароль'),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('api-change-new'),
                controller: _password,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(labelText: 'Новый пароль'),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('api-change-confirm'),
                controller: _confirm,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Повторите новый пароль',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                _ApiErrorCard(message: _error!),
              ],
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const ValueKey('api-change-submit'),
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.password_rounded),
                label: const Text('Сменить пароль'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
