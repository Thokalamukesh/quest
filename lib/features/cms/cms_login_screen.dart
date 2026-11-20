part of 'cms_screen.dart';

class _LoginPage extends StatefulWidget {
  const _LoginPage({
    required this.api,
    required this.onLogin,
    this.initialError,
  });

  final CmsApi api;
  final ValueChanged<Map<String, dynamic>> onLogin;
  final String? initialError;

  @override
  State<_LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<_LoginPage> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _baseUrl = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  late bool _showServerSettings;
  String? _error;

  @override
  void initState() {
    super.initState();
    _baseUrl.text = widget.api.baseUrl;
    _showServerSettings = !_isValidBaseUrl(_baseUrl.text);
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _baseUrl.dispose();
    super.dispose();
  }

  bool _isValidBaseUrl(String raw) {
    final uri = Uri.tryParse(raw.trim());
    return uri != null &&
        uri.hasAuthority &&
        {'http', 'https'}.contains(uri.scheme);
  }

  String get _serverSummary {
    final uri = Uri.tryParse(_baseUrl.text.trim());
    if (uri != null && uri.hasAuthority) {
      return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
    }
    return 'Not configured';
  }

  Future<void> _submit() async {
    if (!_isValidBaseUrl(_baseUrl.text) && !_showServerSettings) {
      setState(() => _showServerSettings = true);
      return;
    }
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      widget.api.baseUrl = _baseUrl.text;
      final user = await widget.api.login(
        _username.text.trim(),
        _password.text,
      );
      widget.onLogin(user);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final activeError = _error ?? widget.initialError;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEEF3FB), wonderlaCream, Color(0xFFFDF8E7)],
            stops: [0, 0.55, 1],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              if (canPop)
                Positioned(
                  top: 12,
                  left: 16,
                  child: TextButton.icon(
                    onPressed: () => Navigator.maybePop(context),
                    style: TextButton.styleFrom(
                      backgroundColor: wonderlaWhite.withValues(alpha: 0.92),
                      foregroundColor: _ink,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                        side: const BorderSide(color: wonderlaBorder),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text(
                      'Visitor guide',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, canPop ? 64 : 24, 20, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 450),
                    child: Container(
                      decoration: BoxDecoration(
                        color: wonderlaWhite,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: wonderlaBorder),
                        boxShadow: [
                          BoxShadow(
                            color: wonderlaNavy.withValues(alpha: 0.09),
                            blurRadius: 34,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [wonderlaNavy, wonderlaCobalt],
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: wonderlaWhite,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Image.asset(
                                    'assets/images/wonderla_logo.webp',
                                    width: 150,
                                    height: 54,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) => const Text(
                                      'WONDERLA',
                                      style: TextStyle(
                                        color: wonderlaNavy,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const _CmsPillBadge(
                                  label: 'PARK OPERATIONS CMS',
                                  foreground: wonderlaNavy,
                                  background: wonderlaGold,
                                  icon: Icons.verified_user_outlined,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Welcome back',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: wonderlaWhite,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Manage rides, wait times, dining, park maps & QR guides',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: wonderlaWhite.withValues(
                                      alpha: 0.85,
                                    ),
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
                            child: Form(
                              key: _form,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextFormField(
                                    controller: _username,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [
                                      AutofillHints.username,
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'Username',
                                      hintText: 'Enter admin username',
                                      prefixIcon: Icon(Icons.person_outline),
                                    ),
                                    validator: (v) =>
                                        v == null || v.trim().isEmpty
                                        ? 'Enter your username.'
                                        : null,
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _password,
                                    obscureText: !_showPassword,
                                    autofillHints: const [
                                      AutofillHints.password,
                                    ],
                                    onFieldSubmitted: (_) => _submit(),
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      hintText: 'Enter your password',
                                      prefixIcon: const Icon(
                                        Icons.lock_outline,
                                      ),
                                      suffixIcon: IconButton(
                                        tooltip: _showPassword
                                            ? 'Hide password'
                                            : 'Show password',
                                        onPressed: () => setState(
                                          () => _showPassword = !_showPassword,
                                        ),
                                        icon: Icon(
                                          _showPassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                        ),
                                      ),
                                    ),
                                    validator: (v) => v == null || v.isEmpty
                                        ? 'Enter your password.'
                                        : null,
                                  ),
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: wonderlaCream,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: wonderlaBorder),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.cloud_done_outlined,
                                              size: 16,
                                              color:
                                                  _isValidBaseUrl(_baseUrl.text)
                                                  ? wonderlaSuccess
                                                  : wonderlaWarning,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Server: $_serverSummary',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: _ink,
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () => setState(
                                                () => _showServerSettings =
                                                    !_showServerSettings,
                                              ),
                                              style: TextButton.styleFrom(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                    ),
                                              ),
                                              child: Text(
                                                _showServerSettings
                                                    ? 'Hide'
                                                    : 'Change',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (_showServerSettings) ...[
                                          const SizedBox(height: 10),
                                          TextFormField(
                                            controller: _baseUrl,
                                            onChanged: (_) => setState(() {}),
                                            decoration: const InputDecoration(
                                              labelText: 'Backend website URL',
                                              hintText:
                                                  'https://your-domain.com',
                                              helperText:
                                                  'Local dev: http://localhost:3000',
                                              prefixIcon: Icon(
                                                Icons.language_rounded,
                                              ),
                                              isDense: true,
                                            ),
                                            validator: (value) {
                                              if (!_isValidBaseUrl(
                                                value ?? '',
                                              )) {
                                                return 'Enter a valid http or https CMS website URL.';
                                              }
                                              return null;
                                            },
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (activeError != null) ...[
                                    const SizedBox(height: 14),
                                    _CmsAlertBanner(
                                      message: activeError,
                                      tone: _CmsBannerTone.error,
                                    ),
                                  ],
                                  const SizedBox(height: 20),
                                  FilledButton(
                                    onPressed: _busy ? null : _submit,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _brandNavy,
                                      minimumSize: const Size.fromHeight(52),
                                    ),
                                    child: _busy
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text('Sign in to CMS'),
                                              SizedBox(width: 8),
                                              Icon(
                                                Icons.arrow_forward_rounded,
                                                size: 18,
                                              ),
                                            ],
                                          ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Use your Wonderla CMS administrator account. Backend URL is public configuration — never enter server secrets here.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: wonderlaMuted,
                                      fontSize: 11.5,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
