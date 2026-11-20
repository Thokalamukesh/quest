import 'dart:typed_data';
import 'dart:ui' show ImageByteFormat, PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:video_player/video_player.dart';

import 'cms_api.dart';
import '../home/home_shortcut_catalog.dart';
import 'qr_download.dart';
import '../../shared/scroll_reveal.dart';
import '../../shared/wonderla_palette.dart';

part 'cms_login_screen.dart';
part 'cms_admin_dashboard.dart';
part 'cms_record_editor.dart';
part 'cms_image_picker_field.dart';
part 'cms_api_key_card.dart';
part 'cms_users_manager.dart';

const _brandNavy = wonderlaCobalt;
const _ink = wonderlaNavy;

bool _hasValidMapCoordinates(Map<String, dynamic> place) {
  final latitude = double.tryParse('${place['lat']}');
  final longitude = double.tryParse('${place['lng']}');
  return latitude != null &&
      longitude != null &&
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}

class CmsScreen extends StatefulWidget {
  const CmsScreen({super.key, this.api, this.initialUser});

  final CmsApi? api;
  final Map<String, dynamic>? initialUser;

  @override
  State<CmsScreen> createState() => _CmsScreenState();
}

class _CmsScreenState extends State<CmsScreen> {
  late final CmsApi _api = widget.api ?? CmsApi();
  Map<String, dynamic>? _user;
  bool _checking = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialUser != null) {
      _user = Map<String, dynamic>.from(widget.initialUser!);
      _checking = false;
    } else {
      _restoreSession();
    }
  }

  Future<void> _restoreSession() async {
    if (!_api.isConfigured) {
      setState(() => _checking = false);
      return;
    }
    try {
      final result = await _api.session();
      if (result['authenticated'] == true) {
        _user = Map<String, dynamic>.from(result['user'] as Map);
      }
    } catch (_) {}
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return Scaffold(
        backgroundColor: wonderlaCream,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: wonderlaWhite,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: wonderlaBorder),
                  boxShadow: [
                    BoxShadow(
                      color: wonderlaNavy.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: const CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: _brandNavy,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Connecting to Wonderla CMS…',
                style: TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_user == null) {
      return _LoginPage(
        api: _api,
        onLogin: (u) => setState(() {
          _user = u;
          _error = null;
        }),
        initialError: _error,
      );
    }
    return _AdminDashboard(
      api: _api,
      user: _user!,
      onLogout: () async {
        try {
          await _api.logout();
        } catch (_) {}
        if (mounted) setState(() => _user = null);
      },
    );
  }
}

enum _CmsBannerTone { info, success, warning, error }

class _CmsAlertBanner extends StatelessWidget {
  const _CmsAlertBanner({
    required this.message,
    this.tone = _CmsBannerTone.info,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
  });

  final String message;
  final _CmsBannerTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color border, Color fg, IconData icon) = switch (tone) {
      _CmsBannerTone.success => (
        const Color(0xFFECF9F2),
        const Color(0xFFBBE7CF),
        wonderlaSuccess,
        Icons.check_circle_rounded,
      ),
      _CmsBannerTone.warning => (
        const Color(0xFFFFF8E6),
        const Color(0xFFF6D98B),
        wonderlaWarning,
        Icons.warning_amber_rounded,
      ),
      _CmsBannerTone.error => (
        const Color(0xFFFDF0F2),
        const Color(0xFFF3C4CC),
        wonderlaFlagRed,
        Icons.error_outline_rounded,
      ),
      _CmsBannerTone.info => (
        const Color(0xFFEEF4FF),
        const Color(0xFFC8DAFA),
        _brandNavy,
        Icons.info_outline_rounded,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: fg,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              tooltip: 'Dismiss',
              icon: Icon(Icons.close_rounded, size: 18, color: fg),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

class _CmsPillBadge extends StatelessWidget {
  const _CmsPillBadge({
    required this.label,
    required this.foreground,
    required this.background,
    this.icon,
    this.borderColor,
  });

  final String label;
  final Color foreground;
  final Color background;
  final IconData? icon;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: borderColor ?? foreground.withValues(alpha: 0.16),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: foreground,
              height: 1.1,
            ),
          ),
        ),
      ],
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard(
    this.title,
    this.subtitle, {
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Card(
    color: wonderlaWhite,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF4FF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 28, color: _brandNavy),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _ink,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: wonderlaMuted,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    ),
  );
}
