import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/wonderla_palette.dart';
import 'wonderla_ai_service.dart';

/// Floating Wonderla mascot button ("Ask Chiku") that launches Chiku's
/// streaming park concierge from Visitor Home or the Park Map.
class WonderlaAiFab extends StatelessWidget {
  const WonderlaAiFab({
    super.key,
    required this.onTap,
    this.compact = false,
  });

  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: EdgeInsets.fromLTRB(5, 5, compact ? 12 : 16, 5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [wonderlaNavy, wonderlaCobalt],
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: wonderlaGold.withValues(alpha: 0.9),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: wonderlaNavy.withValues(alpha: 0.30),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 36 : 42,
                height: compact ? 36 : 42,
                decoration: BoxDecoration(
                  color: wonderlaWhite,
                  shape: BoxShape.circle,
                  border: Border.all(color: wonderlaGold, width: 1.5),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/wonderla_ai_mascot.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.auto_awesome_rounded,
                    color: wonderlaCobalt,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Text(
                'Ask Chiku',
                style: TextStyle(
                  color: wonderlaWhite,
                  fontWeight: FontWeight.w900,
                  fontSize: compact ? 13.5 : 14.5,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens Chiku's interactive streaming park concierge bottom sheet.
Future<void> showWonderlaAiAssistantSheet(
  BuildContext context, {
  required Map<String, dynamic> parkConfig,
  required String baseUrl,
  WonderlaAiService? aiService,
  ValueChanged<AiSuggestedPlace>? onOpenPlaceOnMap,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _WonderlaAiAssistantSheet(
      parkConfig: parkConfig,
      baseUrl: baseUrl,
      aiService: aiService ?? WonderlaAiService(baseUrl: baseUrl),
      onOpenPlaceOnMap: onOpenPlaceOnMap == null
          ? null
          : (place) {
              Navigator.of(ctx).pop();
              onOpenPlaceOnMap(place);
            },
    ),
  );
}

class _QuickPromptItem {
  const _QuickPromptItem({
    required this.text,
    required this.icon,
    required this.tint,
    required this.iconColor,
  });

  final String text;
  final IconData icon;
  final Color tint;
  final Color iconColor;
}

class _ToolActivity {
  _ToolActivity({required this.tool, required this.label});
  final String tool;
  final String label;
  bool done = false;
}

class _ChatBubbleModel {
  _ChatBubbleModel({
    required this.isUser,
    required this.text,
    this.isStreaming = false,
    List<_ToolActivity>? tools,
    List<AiSuggestedPlace>? places,
  }) : tools = tools ?? [],
       places = places ?? [];

  final bool isUser;
  String text;
  bool isStreaming;
  final List<_ToolActivity> tools;
  final List<AiSuggestedPlace> places;
}

class _WonderlaAiAssistantSheet extends StatefulWidget {
  const _WonderlaAiAssistantSheet({
    required this.parkConfig,
    required this.baseUrl,
    required this.aiService,
    this.onOpenPlaceOnMap,
  });

  final Map<String, dynamic> parkConfig;
  final String baseUrl;
  final WonderlaAiService aiService;
  final ValueChanged<AiSuggestedPlace>? onOpenPlaceOnMap;

  @override
  State<_WonderlaAiAssistantSheet> createState() =>
      _WonderlaAiAssistantSheetState();
}

class _WonderlaAiAssistantSheetState extends State<_WonderlaAiAssistantSheet> {
  static const _quickPrompts = [
    _QuickPromptItem(
      text: 'Which rides can I do with my 110 cm kid, and plan my next 3 hours?',
      icon: Icons.child_care_rounded,
      tint: Color(0xFFEEF4FF),
      iconColor: wonderlaCobalt,
    ),
    _QuickPromptItem(
      text: 'Plan my rides today',
      icon: Icons.auto_awesome_rounded,
      tint: Color(0xFFFFF6DC),
      iconColor: Color(0xFFB45309),
    ),
    _QuickPromptItem(
      text: 'Shortest wait rides right now',
      icon: Icons.bolt_rounded,
      tint: Color(0xFFECF9F2),
      iconColor: wonderlaSuccess,
    ),
    _QuickPromptItem(
      text: 'Best veg restaurant & directions',
      icon: Icons.restaurant_rounded,
      tint: Color(0xFFFFF1EC),
      iconColor: Color(0xFFEA580C),
    ),
    _QuickPromptItem(
      text: 'Wave pool & show timings',
      icon: Icons.waves_rounded,
      tint: Color(0xFFE6F6FE),
      iconColor: Color(0xFF0284C7),
    ),
  ];

  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatBubbleModel> _messages = [];
  StreamSubscription<AiStreamEvent>? _activeSub;
  bool _streaming = false;

  String get _parkSlug =>
      widget.parkConfig['slug']?.toString().trim().isNotEmpty == true
      ? widget.parkConfig['slug'].toString().trim()
      : 'bengaluru';

  String get _parkName =>
      widget.parkConfig['name']?.toString().trim().isNotEmpty == true
      ? widget.parkConfig['name'].toString().trim()
      : 'Wonderla';

  String get _welcomeText =>
      "Hi! I'm **Chiku**, your **$_parkName** buddy! Ask me which rides fit a **110 cm** kid, plan your next **3 hours**, find short queues, or get directions to any restaurant or ride.";

  @override
  void initState() {
    super.initState();
    _messages.add(_ChatBubbleModel(isUser: false, text: _welcomeText));
  }

  @override
  void dispose() {
    _activeSub?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _inputController.text).trim();
    if (text.isEmpty || _streaming) return;
    _inputController.clear();

    final history = _messages
        .skip(1)
        .where((m) => m.text.trim().isNotEmpty)
        .map(
          (m) => AiHistoryTurn(
            role: m.isUser ? 'user' : 'assistant',
            text: m.text,
          ),
        )
        .toList(growable: false);

    final assistantBubble = _ChatBubbleModel(
      isUser: false,
      text: '',
      isStreaming: true,
    );

    setState(() {
      _messages.add(_ChatBubbleModel(isUser: true, text: text));
      _messages.add(assistantBubble);
      _streaming = true;
    });
    _scrollToBottom();

    if (_activeSub != null) {
      await _activeSub!.cancel();
    }
    _activeSub = widget.aiService
        .ask(
          parkSlug: _parkSlug,
          message: text,
          parkConfig: widget.parkConfig,
          history: history,
        )
        .listen(
          (event) {
            if (!mounted) return;
            setState(() {
              switch (event) {
                case AiToolStatusEvent(:final tool, :final label):
                  for (final t in assistantBubble.tools) {
                    t.done = true;
                  }
                  assistantBubble.tools.add(
                    _ToolActivity(tool: tool, label: label),
                  );
                case AiTextChunkEvent(text: final chunk):
                  for (final t in assistantBubble.tools) {
                    t.done = true;
                  }
                  assistantBubble.text += chunk;
                case AiPlacesEvent(:final places):
                  assistantBubble.places
                    ..clear()
                    ..addAll(places);
                case AiDoneEvent():
                  for (final t in assistantBubble.tools) {
                    t.done = true;
                  }
                  assistantBubble.isStreaming = false;
                  _streaming = false;
                case AiErrorEvent(:final message):
                  for (final t in assistantBubble.tools) {
                    t.done = true;
                  }
                  if (assistantBubble.text.isEmpty) {
                    assistantBubble.text = message;
                  }
                  assistantBubble.isStreaming = false;
                  _streaming = false;
              }
            });
            _scrollToBottom();
          },
          onDone: () {
            if (!mounted) return;
            setState(() {
              for (final t in assistantBubble.tools) {
                t.done = true;
              }
              assistantBubble.isStreaming = false;
              _streaming = false;
            });
          },
          onError: (_) {
            if (!mounted) return;
            setState(() {
              for (final t in assistantBubble.tools) {
                t.done = true;
              }
              if (assistantBubble.text.isEmpty) {
                assistantBubble.text =
                    'Chiku could not connect right now. Please try again in a moment.';
              }
              assistantBubble.isStreaming = false;
              _streaming = false;
            });
          },
        );
  }

  void _resetChat() {
    _activeSub?.cancel();
    setState(() {
      _streaming = false;
      _messages
        ..clear()
        ..add(_ChatBubbleModel(isUser: false, text: _welcomeText));
    });
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxWidth = screen.width >= 760 ? 560.0 : double.infinity;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: screen.height * 0.89,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF6F8FC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x3D102454),
                  blurRadius: 34,
                  offset: Offset(0, -10),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  _header(),
                  Expanded(
                    child: ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                      children: [
                        for (final msg in _messages) _messageTile(msg),
                        if (_messages.length == 1) _quickPromptCards(),
                      ],
                    ),
                  ),
                  _composer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 10, 14),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [wonderlaNavy, wonderlaCobalt],
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: wonderlaWhite.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: wonderlaWhite,
                    shape: BoxShape.circle,
                    border: Border.all(color: wonderlaGold, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: wonderlaNavy.withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/images/wonderla_ai_mascot.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.auto_awesome_rounded,
                      color: wonderlaCobalt,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(color: wonderlaNavy, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Ask Chiku',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: wonderlaWhite,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: wonderlaGold,
                        size: 16,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_parkName · Live Park Guide',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: wonderlaWhite.withValues(alpha: 0.86),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'New chat',
              onPressed: _resetChat,
              style: IconButton.styleFrom(
                backgroundColor: wonderlaWhite.withValues(alpha: 0.12),
              ),
              icon: const Icon(
                Icons.refresh_rounded,
                color: wonderlaWhite,
                size: 20,
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
              style: IconButton.styleFrom(
                backgroundColor: wonderlaWhite.withValues(alpha: 0.12),
              ),
              icon: const Icon(
                Icons.close_rounded,
                color: wonderlaWhite,
                size: 20,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _quickPromptCards() => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'TRY ASKING CHIKU',
            style: TextStyle(
              color: wonderlaMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
        ),
        for (final prompt in _quickPrompts)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: wonderlaWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: wonderlaBorder),
              ),
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _send(prompt.text),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: prompt.tint,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          prompt.icon,
                          size: 18,
                          color: prompt.iconColor,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          prompt.text,
                          style: const TextStyle(
                            color: wonderlaNavy,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.32,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 13,
                        color: wonderlaMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _messageTile(_ChatBubbleModel msg) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14, left: 44),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [wonderlaCobalt, wonderlaNavy],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(6),
            ),
            boxShadow: [
              BoxShadow(
                color: wonderlaCobalt.withValues(alpha: 0.22),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            msg.text,
            style: const TextStyle(
              color: wonderlaWhite,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.42,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14, right: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            margin: const EdgeInsets.only(top: 18),
            decoration: BoxDecoration(
              color: wonderlaWhite,
              shape: BoxShape.circle,
              border: Border.all(color: wonderlaGold, width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: wonderlaNavy.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/images/wonderla_ai_mascot.png',
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.auto_awesome_rounded,
                color: wonderlaCobalt,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Row(
                    children: [
                      const Text(
                        'Chiku',
                        style: TextStyle(
                          color: wonderlaMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (msg.isStreaming) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4D6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Typing',
                            style: TextStyle(
                              color: wonderlaNavy,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: wonderlaWhite,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    border: Border.all(color: wonderlaBorder),
                    boxShadow: [
                      BoxShadow(
                        color: wonderlaNavy.withValues(alpha: 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (msg.tools.isNotEmpty) ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final t in msg.tools)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: t.done
                                      ? const Color(0xFFECF9F2)
                                      : const Color(0xFFEEF4FF),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: t.done
                                        ? const Color(0xFFBBE7CF)
                                        : const Color(0xFFC8DAFA),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (t.done)
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        size: 13.5,
                                        color: wonderlaSuccess,
                                      )
                                    else
                                      const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.8,
                                          color: wonderlaCobalt,
                                        ),
                                      ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        t.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: t.done
                                              ? wonderlaSuccess
                                              : wonderlaCobalt,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (msg.text.isNotEmpty)
                        _RichAiText(
                          text: msg.isStreaming ? '${msg.text} ▍' : msg.text,
                        )
                      else if (msg.isStreaming)
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: wonderlaCobalt,
                              ),
                            ),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Chiku is checking live park info…',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: wonderlaMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (msg.places.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _AiPlaceCardStrip(
                          places: msg.places,
                          parkConfig: widget.parkConfig,
                          baseUrl: widget.baseUrl,
                          onTapPlace: widget.onOpenPlaceOnMap,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _composer() => Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
    decoration: BoxDecoration(
      color: wonderlaWhite,
      border: const Border(top: BorderSide(color: wonderlaBorder)),
      boxShadow: [
        BoxShadow(
          color: wonderlaNavy.withValues(alpha: 0.04),
          blurRadius: 10,
          offset: const Offset(0, -3),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: _inputController,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            style: const TextStyle(
              color: wonderlaNavy,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'Ask Chiku about rides, food, or directions…',
              hintStyle: const TextStyle(
                color: wonderlaMuted,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              filled: true,
              fillColor: const Color(0xFFF3F6FC),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: wonderlaBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: wonderlaBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(
                  color: wonderlaCobalt,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        FilledButton(
          onPressed: _streaming ? null : () => _send(),
          style: FilledButton.styleFrom(
            backgroundColor: wonderlaCobalt,
            disabledBackgroundColor: wonderlaCobalt.withValues(alpha: 0.55),
            minimumSize: const Size(46, 46),
            padding: EdgeInsets.zero,
            shape: const CircleBorder(),
          ),
          child: _streaming
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send_rounded, size: 20, color: Colors.white),
        ),
      ],
    ),
  );
}

class _AiPlaceCardStrip extends StatelessWidget {
  const _AiPlaceCardStrip({
    required this.places,
    required this.parkConfig,
    required this.baseUrl,
    this.onTapPlace,
  });

  final List<AiSuggestedPlace> places;
  final Map<String, dynamic> parkConfig;
  final String baseUrl;
  final ValueChanged<AiSuggestedPlace>? onTapPlace;

  String _resolveImageUrl(AiSuggestedPlace place) {
    var raw = place.imageUrl?.trim() ?? '';
    if (raw.isEmpty) {
      raw = _findImageInConfig(place.name) ?? '';
    }
    if (raw.isEmpty) return '';
    if (Uri.tryParse(raw)?.hasScheme == true) return raw;
    final cleanBase = baseUrl.trim().replaceAll(RegExp(r'/$'), '');
    if (cleanBase.isEmpty) return raw;
    return '$cleanBase${raw.startsWith('/') ? '' : '/'}$raw';
  }

  String? _findImageInConfig(String placeName) {
    final target = placeName.trim().toLowerCase();
    if (target.isEmpty) return null;

    String? searchList(dynamic raw, List<String> titleKeys, String imgKey) {
      if (raw is! List) return null;
      for (final item in raw.whereType<Map>()) {
        final name = titleKeys
            .map((k) => item[k]?.toString().trim() ?? '')
            .firstWhere((v) => v.isNotEmpty, orElse: () => '');
        if (name.toLowerCase() == target ||
            name.toLowerCase().contains(target) ||
            target.contains(name.toLowerCase())) {
          final img = item[imgKey]?.toString().trim() ?? '';
          if (img.isNotEmpty) return img;
        }
      }
      return null;
    }

    return searchList(parkConfig['rides'], const ['title', 'name'], 'img') ??
        searchList(parkConfig['dining'], const ['name', 'title'], 'img') ??
        searchList(parkConfig['waveRainDance'], const ['title', 'name'], 'img') ??
        searchList(parkConfig['events'], const ['title', 'name'], 'img') ??
        searchList(
          (parkConfig['parkMap'] as Map?)?['places'],
          const ['name', 'title'],
          'avatarImage',
        );
  }

  @override
  Widget build(BuildContext context) {
    if (places.length == 1) {
      final place = places.first;
      return _AiPlaceCard(
        place: place,
        imageUrl: _resolveImageUrl(place),
        onTap: onTapPlace == null ? null : () => onTapPlace!(place),
      );
    }

    return SizedBox(
      height: 222,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: places.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          final place = places[index];
          return SizedBox(
            width: 216,
            child: _AiPlaceCard(
              place: place,
              imageUrl: _resolveImageUrl(place),
              onTap: onTapPlace == null ? null : () => onTapPlace!(place),
            ),
          );
        },
      ),
    );
  }
}

class _AiPlaceCard extends StatelessWidget {
  const _AiPlaceCard({
    required this.place,
    required this.imageUrl,
    this.onTap,
  });

  final AiSuggestedPlace place;
  final String imageUrl;
  final VoidCallback? onTap;

  IconData _categoryIcon() {
    final c = place.category.toLowerCase();
    if (c.contains('dining') || c.contains('food') || c.contains('restaurant')) {
      return Icons.restaurant_rounded;
    }
    if (c.contains('water') || c.contains('wave')) {
      return Icons.waves_rounded;
    }
    if (c.contains('event') || c.contains('show')) {
      return Icons.celebration_rounded;
    }
    if (c.contains('kid') || c.contains('family')) {
      return Icons.child_care_rounded;
    }
    return Icons.attractions_rounded;
  }

  List<Color> _fallbackGradient() {
    final c = place.category.toLowerCase();
    if (c.contains('dining') || c.contains('food')) {
      return const [Color(0xFF9A3412), Color(0xFFEA580C)];
    }
    if (c.contains('water') || c.contains('wave')) {
      return const [Color(0xFF0369A1), Color(0xFF0EA5E9)];
    }
    return const [wonderlaNavy, wonderlaCobalt];
  }

  @override
  Widget build(BuildContext context) {
    final badgeText = (place.badge?.trim().isNotEmpty == true)
        ? place.badge!.trim()
        : place.category;
    final isPositiveBadge =
        badgeText.toLowerCase().contains('wait') ||
        badgeText.toLowerCase().contains('veg');
    final subtitleText =
        place.subtitle?.trim().isNotEmpty == true
        ? place.subtitle!.trim()
        : place.directions?.trim().isNotEmpty == true
        ? place.directions!.trim()
        : place.category;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: wonderlaBorder),
        boxShadow: [
          BoxShadow(
            color: wonderlaNavy.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 104,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _imageFallback(),
                if (imageUrl.isNotEmpty)
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _imageFallback(),
                  ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x28071A3D),
                        Color(0x00071A3D),
                        Color(0x78071A3D),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: isPositiveBadge
                          ? const Color(0xEBECF9F2)
                          : const Color(0xEB0F2357),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isPositiveBadge
                            ? const Color(0xFFBBE7CF)
                            : wonderlaGold.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Text(
                      badgeText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isPositiveBadge ? wonderlaSuccess : wonderlaGold,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  place.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: wonderlaNavy,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitleText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: wonderlaMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 34,
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEEF4FF),
                      foregroundColor: wonderlaCobalt,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFC8DAFA)),
                      ),
                    ),
                    onPressed: onTap,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          place.prefersDirections
                              ? Icons.directions_rounded
                              : Icons.map_outlined,
                          size: 15,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            place.prefersDirections
                                ? 'Directions · ${place.name}'
                                : 'Map · ${place.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageFallback() => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _fallbackGradient(),
      ),
    ),
    child: Center(
      child: Icon(
        _categoryIcon(),
        size: 36,
        color: wonderlaGold.withValues(alpha: 0.92),
      ),
    ),
  );
}

class _RichAiText extends StatelessWidget {
  const _RichAiText({required this.text});

  final String text;

  List<TextSpan> _parseInline(String line, {bool isHeading = false}) {
    final spans = <TextSpan>[];
    final parts = line.split('**');
    for (var i = 0; i < parts.length; i++) {
      final segment = parts[i];
      if (segment.isEmpty) continue;
      if (i.isOdd) {
        spans.add(
          TextSpan(
            text: segment,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: wonderlaNavy,
              fontSize: isHeading ? 14.3 : 13.8,
            ),
          ),
        );
      } else {
        // Parse subtle *italic* phrases inside regular text cleanly.
        final italicParts = segment.split('*');
        for (var j = 0; j < italicParts.length; j++) {
          if (italicParts[j].isEmpty) continue;
          spans.add(
            TextSpan(
              text: italicParts[j],
              style: TextStyle(
                fontWeight: isHeading ? FontWeight.w800 : FontWeight.w500,
                fontStyle: j.isOdd ? FontStyle.italic : FontStyle.normal,
                color: wonderlaNavy,
                fontSize: isHeading ? 14.3 : 13.8,
              ),
            ),
          );
        }
      }
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final rawLines = text.split('\n');
    final blocks = <Widget>[];

    for (var i = 0; i < rawLines.length; i++) {
      final trimmed = rawLines[i].trim();
      if (trimmed.isEmpty) continue;

      final isBullet =
          trimmed.startsWith('• ') ||
          trimmed.startsWith('- ') ||
          trimmed.startsWith('* ');
      final isHeading =
          !isBullet &&
          trimmed.startsWith('**') &&
          (trimmed.endsWith('**') || trimmed.endsWith(':**'));

      if (isBullet) {
        final content = trimmed.substring(2).trim();
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 7.5, right: 8),
                  decoration: const BoxDecoration(
                    color: wonderlaCobalt,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        color: wonderlaNavy,
                        fontSize: 13.8,
                        height: 1.48,
                      ),
                      children: _parseInline(content),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        blocks.add(
          Padding(
            padding: EdgeInsets.only(
              top: blocks.isEmpty ? 0 : (isHeading ? 10 : 6),
            ),
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: wonderlaNavy,
                  fontSize: isHeading ? 14.3 : 13.8,
                  fontWeight: isHeading ? FontWeight.w800 : FontWeight.w500,
                  height: 1.5,
                ),
                children: _parseInline(trimmed, isHeading: isHeading),
              ),
            ),
          ),
        );
      }
    }

    if (blocks.isEmpty) {
      return Text(
        text,
        style: const TextStyle(
          fontFamily: 'Roboto',
          color: wonderlaNavy,
          fontSize: 13.8,
          height: 1.5,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks,
    );
  }
}
