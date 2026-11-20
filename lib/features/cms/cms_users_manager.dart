part of 'cms_screen.dart';

class _UsersManager extends StatefulWidget {
  const _UsersManager({
    required this.api,
    required this.users,
    required this.parks,
    required this.currentUsername,
    required this.reload,
  });

  final CmsApi api;
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> parks;
  final String currentUsername;
  final Future<void> Function() reload;

  @override
  State<_UsersManager> createState() => _UsersManagerState();
}

class _UsersManagerState extends State<_UsersManager> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  String _role = 'park';
  bool _allAccess = true;
  bool _showPassword = false;
  final Set<String> _selectedAccess = {};
  static const _accessSections = [
    'Park overview',
    'Home card labels',
    'Rides',
    'Events',
    'Dining & menus',
    'Live wait times',
    'Wave pool & rain dance',
    'Safety & hygiene',
    'Maintenance log',
    'Ride guidelines',
    'Park map & places',
  ];
  String? _park;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    if (widget.parks.isNotEmpty) _park = widget.parks.first['slug'] as String;
  }

  @override
  void didUpdateWidget(covariant _UsersManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_park == null && widget.parks.isNotEmpty) {
      _park = widget.parks.first['slug'] as String;
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _canCreate =>
      !_busy &&
      _username.text.trim().isNotEmpty &&
      _password.text.length >= 6 &&
      (_role != 'park' || _allAccess || _selectedAccess.isNotEmpty);

  Future<void> _create() async {
    if (!_canCreate) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    final createdUsername = _username.text.trim();
    try {
      await widget.api.createUser({
        'username': createdUsername,
        'password': _password.text,
        'role': _role,
        if (_role == 'park') 'parkSlug': _park,
        if (_role == 'park')
          'permissions': _allAccess ? ['all'] : _selectedAccess.toList(),
      });
      _username.clear();
      _password.clear();
      await widget.reload();
      if (mounted) {
        setState(() => _notice = 'Account "$createdUsername" created.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(String username) async {
    if (username == widget.currentUsername) return;
    final yes =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF0F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person_remove_outlined,
                    color: wonderlaFlagRed,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Remove admin user?')),
              ],
            ),
            content: Text(
              'Remove CMS access for "$username"? They will immediately be unable to sign in.',
              style: const TextStyle(color: wonderlaMuted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: wonderlaFlagRed),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Remove user'),
              ),
            ],
          ),
        ) ??
        false;
    if (!yes) return;
    try {
      await widget.api.deleteUser(username);
      await widget.reload();
      if (mounted) {
        setState(() {
          _error = null;
          _notice = 'Removed "$username".';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _editAccess(Map<String, dynamic> user) async {
    if (user['role'] != 'park' || user['username'] == widget.currentUsername) {
      return;
    }
    final current = List<String>.from(
      user['permissions'] as List? ?? const ['all'],
    );
    var all = current.contains('all');
    final selected = <String>{if (!all) ...current};
    final result = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) => AlertDialog(
          title: Text('Section access · ${user['username']}'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    color: wonderlaCream,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: wonderlaBorder),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SwitchListTile(
                      title: const Text(
                        'All park sections',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text(
                        'Allow editing every content area for this park.',
                      ),
                      value: all,
                      onChanged: (v) => refresh(() => all = v),
                    ),
                  ),
                  if (!all) ...[
                    const SizedBox(height: 10),
                    for (final section in _accessSections)
                      CheckboxListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        title: Text(section),
                        value: selected.contains(section),
                        onChanged: (v) => refresh(
                          () => v == true
                              ? selected.add(section)
                              : selected.remove(section),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: !all && selected.isEmpty
                  ? null
                  : () => Navigator.pop(ctx, all ? ['all'] : selected.toList()),
              child: const Text('Save access'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    try {
      await widget.api.updateUserPermissions(
        user['username'] as String,
        result,
      );
      await widget.reload();
      if (mounted) {
        setState(() {
          _error = null;
          _notice = 'Updated section access for "${user['username']}".';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  String _permissionSummary(Map<String, dynamic> user) {
    if (user['role'] == 'superadmin') return 'Full platform access';
    final perms = List<String>.from(
      user['permissions'] as List? ?? const ['all'],
    );
    if (perms.contains('all') || perms.isEmpty) return 'All park sections';
    return '${perms.length} ${perms.length == 1 ? 'section' : 'sections'}';
  }

  String _parkNameFor(String? slug) {
    if (slug == null || slug.isEmpty) return 'All parks';
    for (final p in widget.parks) {
      if (p['slug'] == slug) return p['name']?.toString() ?? slug;
    }
    return slug;
  }

  Widget _usersListCard() => Card(
    color: wonderlaWhite,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Team accounts',
                      style: TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Manage superadmins and park-specific editors.',
                      style: TextStyle(color: wonderlaMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              _CmsPillBadge(
                label: '${widget.users.length} users',
                foreground: _brandNavy,
                background: const Color(0xFFEEF4FF),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.users.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No CMS accounts found.',
                textAlign: TextAlign.center,
                style: TextStyle(color: wonderlaMuted),
              ),
            )
          else
            for (var i = 0; i < widget.users.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _userRow(widget.users[i]),
            ],
        ],
      ),
    ),
  );

  Widget _userRow(Map<String, dynamic> u) {
    final isSuper = u['role'] == 'superadmin';
    final isMe = u['username'] == widget.currentUsername;
    final username = u['username']?.toString() ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFFF6F9FF) : wonderlaCream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe ? _brandNavy.withValues(alpha: 0.25) : wonderlaBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isSuper
                  ? wonderlaGold.withValues(alpha: 0.28)
                  : const Color(0xFFE7EFFD),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              isSuper
                  ? Icons.admin_panel_settings_outlined
                  : Icons.person_outline_rounded,
              color: isSuper ? wonderlaNavy : _brandNavy,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      username,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                    _CmsPillBadge(
                      label: isSuper ? 'Superadmin' : 'Park editor',
                      foreground: isSuper ? wonderlaNavy : _brandNavy,
                      background: isSuper
                          ? wonderlaGold.withValues(alpha: 0.35)
                          : const Color(0xFFEEF4FF),
                    ),
                    if (isMe)
                      const _CmsPillBadge(
                        label: 'You',
                        foreground: wonderlaSuccess,
                        background: Color(0xFFECF9F2),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_parkNameFor(u['parkSlug']?.toString())} · ${_permissionSummary(u)}',
                  style: const TextStyle(color: wonderlaMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          if (!isMe) ...[
            if (!isSuper)
              IconButton(
                tooltip: 'Edit section access',
                onPressed: () => _editAccess(u),
                icon: const Icon(Icons.tune_rounded, color: _brandNavy),
              ),
            IconButton(
              tooltip: 'Remove user',
              onPressed: () => _delete(username),
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: wonderlaFlagRed,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _createUserCard() {
    final pwdLen = _password.text.length;
    return Card(
      color: wonderlaWhite,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF4FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: _brandNavy,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add admin user',
                        style: TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        'Grant access to manage a park or the full CMS.',
                        style: TextStyle(color: wonderlaMuted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _username,
              onChanged: (_) => setState(() {
                _error = null;
                _notice = null;
              }),
              decoration: const InputDecoration(
                labelText: 'Username',
                hintText: 'e.g. bengaluru_ops',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: !_showPassword,
              onChanged: (_) => setState(() {
                _error = null;
                _notice = null;
              }),
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'At least 6 characters',
                helperText: pwdLen > 0 && pwdLen < 6
                    ? '${6 - pwdLen} more character${6 - pwdLen == 1 ? '' : 's'} required'
                    : 'Minimum 6 characters',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _showPassword ? 'Hide password' : 'Show password',
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(
                labelText: 'Role',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'park', child: Text('Park editor')),
                DropdownMenuItem(
                  value: 'superadmin',
                  child: Text('Superadmin'),
                ),
              ],
              onChanged: (v) => setState(() => _role = v ?? 'park'),
            ),
            if (_role == 'park' && widget.parks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: DropdownButtonFormField<String>(
                  initialValue: _park,
                  decoration: const InputDecoration(
                    labelText: 'Assigned park',
                    prefixIcon: Icon(Icons.park_outlined),
                  ),
                  items: [
                    for (final p in widget.parks)
                      DropdownMenuItem(
                        value: p['slug'] as String,
                        child: Text(p['name'] as String),
                      ),
                  ],
                  onChanged: (v) => setState(() => _park = v),
                ),
              ),
            if (_role == 'park') ...[
              const SizedBox(height: 14),
              Material(
                color: wonderlaCream,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: wonderlaBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: SwitchListTile(
                  title: const Text(
                    'Access to all sections',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Turn off to grant specific sections only.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                  value: _allAccess,
                  onChanged: (value) => setState(() => _allAccess = value),
                ),
              ),
              if (!_allAccess) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final section in _accessSections)
                      FilterChip(
                        label: Text(
                          section,
                          style: TextStyle(
                            color: _selectedAccess.contains(section)
                                ? wonderlaWhite
                                : _ink,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                        checkmarkColor: wonderlaWhite,
                        selected: _selectedAccess.contains(section),
                        onSelected: (selected) => setState(() {
                          selected
                              ? _selectedAccess.add(section)
                              : _selectedAccess.remove(section);
                        }),
                      ),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _canCreate ? _create : null,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: Text(_busy ? 'Creating…' : 'Create user'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_notice != null) ...[
        _CmsAlertBanner(
          message: _notice!,
          tone: _CmsBannerTone.success,
          onDismiss: () => setState(() => _notice = null),
        ),
        const SizedBox(height: 14),
      ],
      if (_error != null) ...[
        _CmsAlertBanner(
          message: _error!,
          tone: _CmsBannerTone.error,
          onDismiss: () => setState(() => _error = null),
        ),
        const SizedBox(height: 14),
      ],
      LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 900) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: _usersListCard()),
                const SizedBox(width: 18),
                Expanded(flex: 5, child: _createUserCard()),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _usersListCard(),
              const SizedBox(height: 16),
              _createUserCard(),
            ],
          );
        },
      ),
    ],
  );
}
