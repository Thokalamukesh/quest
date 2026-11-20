part of 'cms_screen.dart';

class _ApiKeyCard extends StatefulWidget {
  const _ApiKeyCard({
    required this.api,
    required this.configured,
    required this.onSaved,
  });

  final CmsApi api;
  final bool configured;
  final VoidCallback onSaved;

  @override
  State<_ApiKeyCard> createState() => _ApiKeyCardState();
}

class _ApiKeyCardState extends State<_ApiKeyCard> {
  final _controller = TextEditingController();
  bool _configured = false;
  bool _saving = false;
  bool _obscure = true;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    _configured = widget.configured;
  }

  @override
  void didUpdateWidget(covariant _ApiKeyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.configured != widget.configured) {
      _configured = widget.configured;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
      _message = null;
    });
    try {
      await widget.api.saveMapSettings(trimmed);
      if (!mounted) return;
      setState(() {
        _configured = trimmed.isNotEmpty;
        _message = 'Google Maps API key saved successfully.';
        _controller.clear();
      });
      widget.onSaved();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    color: wonderlaWhite,
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF4FF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.key_rounded, color: _brandNavy),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Google Maps API key',
                      style: TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Used by the web visitor map for tiles & walking directions.',
                      style: TextStyle(color: wonderlaMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _CmsPillBadge(
                label: _configured ? 'Configured' : 'Not configured',
                foreground: _configured ? wonderlaSuccess : wonderlaWarning,
                background: _configured
                    ? const Color(0xFFECF9F2)
                    : const Color(0xFFFFF8E6),
                icon: _configured
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'The existing React map reads this key from the admin API. Keys stay hidden after saving — paste a new browser API key below whenever you need to rotate or replace it.',
            style: TextStyle(color: wonderlaMuted, fontSize: 13.5, height: 1.5),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _controller,
            obscureText: _obscure,
            onChanged: (_) => setState(() {
              _error = null;
              _message = null;
            }),
            onSubmitted: (_) {
              if (!_saving && _controller.text.trim().isNotEmpty) _save();
            },
            decoration: InputDecoration(
              labelText: _configured
                  ? 'Replacement browser API key'
                  : 'Google Maps browser API key',
              hintText: 'AIza...',
              prefixIcon: const Icon(Icons.vpn_key_outlined),
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Show key' : 'Hide key',
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            _CmsAlertBanner(
              message: _message!,
              tone: _CmsBannerTone.success,
              onDismiss: () => setState(() => _message = null),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            _CmsAlertBanner(
              message: _error!,
              tone: _CmsBannerTone.error,
              onDismiss: () => setState(() => _error = null),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _saving || _controller.text.trim().isEmpty
                    ? null
                    : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(_saving ? 'Saving…' : 'Save API key'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _CmsAlertBanner(
            tone: _CmsBannerTone.info,
            message:
                'Security tip: restrict this browser key in Google Cloud Console to required Maps APIs and your production web domains. Never enter server secrets here.',
          ),
        ],
      ),
    ),
  );
}
