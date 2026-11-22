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
    required this.aiService,
    this.onOpenPlaceOnMap,
  });

  final Map<String, dynamic> parkConfig;
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
                      if (msg.places.isNotEmpty &&
                          widget.onOpenPlaceOnMap != null) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            for (final place in msg.places)
                              FilledButton.tonalIcon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFEEF4FF),
                                  foregroundColor: wonderlaCobalt,
                                  minimumSize: const Size(0, 36),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 11,
                                    vertical: 6,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: const BorderSide(
                                      color: Color(0xFFC8DAFA),
                                    ),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                onPressed: () =>
                                    widget.onOpenPlaceOnMap!(place),
                                icon: Icon(
                                  place.prefersDirections
                                      ? Icons.directions_rounded
                                      : Icons.map_outlined,
                                  size: 15,
                                ),
                                label: Text(
                                  place.prefersDirections
                                      ? 'Directions · ${place.name}'
                                      : 'Map · ${place.name}',
                                ),
                              ),
                          ],
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

class _RichAiText extends StatelessWidget {
  const _RichAiText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final parts = text.split('**');
    for (var i = 0; i < parts.length; i++) {
      spans.add(
        TextSpan(
          text: parts[i],
          style: TextStyle(
            fontWeight: i.isOdd ? FontWeight.w800 : FontWeight.w500,
            color: wonderlaNavy,
          ),
        ),
      );
    }
    return Text.rich(
      TextSpan(
        style: const TextStyle(
          fontFamily: 'Roboto',
          color: wonderlaNavy,
          fontSize: 13.8,
          height: 1.52,
        ),
        children: spans,
      ),
    );
  }
}
