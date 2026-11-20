import 'package:flutter/material.dart';

import '../../../shared/wonderla_palette.dart';
import '../models/park_discovery_item.dart';
import 'park_map_marker.dart';

/// Opens a Disneyland-inspired, Wonderla-branded information bottom sheet for
/// any selected ride, dining outlet, water attraction, or facility.
Future<void> showParkPlaceDetailSheet(
  BuildContext context, {
  required ParkDiscoveryItem item,
  String? distanceLabel,
  bool routing = false,
  VoidCallback? onDirections,
  VoidCallback? onShowOnGuideMap,
  VoidCallback? onViewDetails,
  String? viewDetailsLabel,
  VoidCallback? onLocateOnMap,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ParkPlaceDetailSheet(
      item: item,
      distanceLabel: distanceLabel,
      routing: routing,
      onDirections: onDirections == null
          ? null
          : () {
              Navigator.of(ctx).pop();
              onDirections();
            },
      onShowOnGuideMap: onShowOnGuideMap == null
          ? null
          : () {
              Navigator.of(ctx).pop();
              onShowOnGuideMap();
            },
      onViewDetails: onViewDetails == null
          ? null
          : () {
              Navigator.of(ctx).pop();
              onViewDetails();
            },
      viewDetailsLabel: viewDetailsLabel,
      onLocateOnMap: onLocateOnMap == null
          ? null
          : () {
              Navigator.of(ctx).pop();
              onLocateOnMap();
            },
    ),
  );
}

class ParkPlaceDetailSheet extends StatelessWidget {
  const ParkPlaceDetailSheet({
    super.key,
    required this.item,
    this.distanceLabel,
    this.routing = false,
    this.onDirections,
    this.onShowOnGuideMap,
    this.onViewDetails,
    this.viewDetailsLabel,
    this.onLocateOnMap,
  });

  final ParkDiscoveryItem item;
  final String? distanceLabel;
  final bool routing;
  final VoidCallback? onDirections;
  final VoidCallback? onShowOnGuideMap;
  final VoidCallback? onViewDetails;
  final String? viewDetailsLabel;
  final VoidCallback? onLocateOnMap;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final maxWidth = MediaQuery.sizeOf(context).width >= 760 ? 540.0 : double.infinity;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: screenHeight * 0.86,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Color(0x33102454),
                blurRadius: 28,
                offset: Offset(0, -6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeroHeader(item: item),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      color: wonderlaNavy,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      height: 1.15,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      _MetaPill(
                                        icon: item.icon,
                                        label: item.category.label,
                                        color: item.category.color,
                                        tint: item.category.tintColor,
                                      ),
                                      if (item.cuisine != null)
                                        _MetaPill(
                                          icon: Icons.restaurant_menu_rounded,
                                          label: item.cuisine!,
                                          color: wonderlaNavy,
                                          tint: wonderlaCream,
                                        ),
                                      if (item.zoneName != null)
                                        _MetaPill(
                                          icon: Icons.layers_outlined,
                                          label: item.zoneName!,
                                          color: wonderlaNavy,
                                          tint: wonderlaCream,
                                        ),
                                      if (distanceLabel != null)
                                        _MetaPill(
                                          icon: Icons.directions_walk_rounded,
                                          label: distanceLabel!,
                                          color: wonderlaCobalt,
                                          tint: const Color(0xFFE8F0FE),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_hasRealStats) ...[
                          const SizedBox(height: 16),
                          _StatsStrip(item: item),
                        ],
                        if (item.sessionTimeSlots.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _WaterSessionsCard(
                            slots: item.sessionTimeSlots,
                            durationMinutes: item.sessionDurationMinutes,
                          ),
                        ],
                        if (item.description.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            item.description,
                            style: const TextStyle(
                              color: wonderlaNavy,
                              fontSize: 14.5,
                              height: 1.5,
                            ),
                          ),
                        ] else if (item.address != null &&
                            item.address!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            item.address!,
                            style: const TextStyle(
                              color: wonderlaMuted,
                              fontSize: 13.5,
                              height: 1.4,
                            ),
                          ),
                        ],
                        if (item.tags.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: [
                              for (final tag in item.tags)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: wonderlaCream,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: wonderlaBorder),
                                  ),
                                  child: Text(
                                    tag,
                                    style: const TextStyle(
                                      color: wonderlaNavy,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                        if (item.menuItems.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _MenuPreviewCard(menuItems: item.menuItems),
                        ],
                        if (item.kioskBookingEnabled) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: wonderlaGold.withValues(alpha: .16),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: wonderlaGold.withValues(alpha: .75),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.confirmation_number_outlined,
                                  color: wonderlaNavy,
                                  size: 22,
                                ),
                                SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Book a ride slot at park kiosks',
                                        style: TextStyle(
                                          color: wonderlaNavy,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Kiosk reservation is available for this ride.',
                                        style: TextStyle(
                                          color: wonderlaNavy,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        _ActionButtons(
                          item: item,
                          routing: routing,
                          onDirections: onDirections,
                          onShowOnGuideMap: onShowOnGuideMap,
                          onViewDetails: onViewDetails,
                          viewDetailsLabel: viewDetailsLabel,
                          onLocateOnMap: onLocateOnMap,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _hasRealStats =>
      item.waitTimeMinutes != null ||
      item.minHeight != null ||
      item.operatingStatus != null ||
      item.lastServiceDate != null;
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.item});

  final ParkDiscoveryItem item;

  @override
  Widget build(BuildContext context) {
    final hasImage = item.imageUrl.isNotEmpty;
    return SizedBox(
      height: hasImage ? 196 : 124,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage)
            Image.network(
              item.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _GradientPlaceholder(item: item),
            )
          else
            _GradientPlaceholder(item: item),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  wonderlaNavy.withValues(alpha: hasImage ? .48 : .12),
                  Colors.transparent,
                  wonderlaNavy.withValues(alpha: hasImage ? .65 : .22),
                ],
              ),
            ),
          ),
          // Drag handle indicator
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 40,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .88),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          // Wait time hero badge when real wait-time API data exists
          if (item.waitTimeMinutes != null)
            Positioned(
              left: 16,
              bottom: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: wonderlaWaitTimeColor(item.waitTimeMinutes!),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x38102454),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${item.waitTimeMinutes} min wait · ${wonderlaWaitTimeCrowdLabel(item.waitTimeMinutes!)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            top: 12,
            right: 12,
            child: Material(
              color: Colors.white.withValues(alpha: .94),
              shape: const CircleBorder(),
              elevation: 3,
              child: IconButton(
                tooltip: 'Close',
                constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.close_rounded,
                  color: wonderlaNavy,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientPlaceholder extends StatelessWidget {
  const _GradientPlaceholder({required this.item});

  final ParkDiscoveryItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            wonderlaNavy,
            item.category.color,
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .16),
            shape: BoxShape.circle,
            border: Border.all(
              color: wonderlaGold.withValues(alpha: .7),
              width: 2,
            ),
          ),
          child: Icon(item.icon, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.5, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.item});

  final ParkDiscoveryItem item;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      if (item.waitTimeMinutes != null)
        _StatBox(
          icon: Icons.timer_outlined,
          label: 'Live Wait',
          value: '${item.waitTimeMinutes} min',
          accent: wonderlaWaitTimeColor(item.waitTimeMinutes!),
        ),
      if (item.minHeight != null)
        _StatBox(
          icon: Icons.straighten_rounded,
          label: 'Min Height',
          value: item.minHeight!,
          accent: wonderlaCobalt,
        ),
      if (item.operatingStatus != null)
        _StatBox(
          icon: Icons.verified_rounded,
          label: 'Status',
          value: item.operatingStatus!,
          accent: wonderlaSuccess,
        ),
      if (item.lastServiceDate != null)
        _StatBox(
          icon: Icons.build_circle_outlined,
          label: 'Last Service',
          value: item.serviceChecks != null
              ? '${item.lastServiceDate} · ${item.serviceChecks} checks'
              : item.lastServiceDate!,
          accent: wonderlaSuccess,
        ),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: cards,
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: wonderlaCream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: wonderlaBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: wonderlaMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: wonderlaNavy,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WaterSessionsCard extends StatelessWidget {
  const _WaterSessionsCard({
    required this.slots,
    this.durationMinutes,
  });

  final List<String> slots;
  final int? durationMinutes;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F6FE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.waves_rounded, color: Color(0xFF0284C7), size: 18),
              const SizedBox(width: 7),
              Text(
                durationMinutes != null
                    ? 'Session Timings · $durationMinutes min each'
                    : 'Session Timings',
                style: const TextStyle(
                  color: wonderlaNavy,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final slot in slots)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    slot,
                    style: const TextStyle(
                      color: wonderlaNavy,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuPreviewCard extends StatelessWidget {
  const _MenuPreviewCard({required this.menuItems});

  final List<Map<String, dynamic>> menuItems;

  @override
  Widget build(BuildContext context) {
    final preview = menuItems.take(3).toList(growable: false);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: wonderlaCream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: wonderlaBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.restaurant_menu_rounded,
                size: 17,
                color: Color(0xFFD97706),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Popular on the menu (${menuItems.length} ${menuItems.length == 1 ? 'item' : 'items'})',
                  style: const TextStyle(
                    color: wonderlaNavy,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < preview.length; i++) ...[
            if (i > 0) const Divider(height: 12),
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: preview[i]['veg'] == true
                        ? wonderlaSuccess
                        : wonderlaFlagRed,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    preview[i]['name']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: wonderlaNavy,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  preview[i]['price']?.toString() ?? '',
                  style: const TextStyle(
                    color: wonderlaNavy,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.item,
    required this.routing,
    this.onDirections,
    this.onShowOnGuideMap,
    this.onViewDetails,
    this.viewDetailsLabel,
    this.onLocateOnMap,
  });

  final ParkDiscoveryItem item;
  final bool routing;
  final VoidCallback? onDirections;
  final VoidCallback? onShowOnGuideMap;
  final VoidCallback? onViewDetails;
  final String? viewDetailsLabel;
  final VoidCallback? onLocateOnMap;

  @override
  Widget build(BuildContext context) {
    final primaryButton = onDirections != null
        ? FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: wonderlaCobalt,
              foregroundColor: Colors.white,
            ),
            onPressed: routing ? null : onDirections,
            icon: routing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.directions_walk_rounded, size: 19),
            label: const Text('Walking Directions'),
          )
        : onLocateOnMap != null
        ? FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: wonderlaCobalt,
              foregroundColor: Colors.white,
            ),
            onPressed: onLocateOnMap,
            icon: const Icon(Icons.map_rounded, size: 19),
            label: const Text('Show on Park Map'),
          )
        : onShowOnGuideMap != null
        ? FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: wonderlaCobalt,
              foregroundColor: Colors.white,
            ),
            onPressed: onShowOnGuideMap,
            icon: const Icon(Icons.explore_rounded, size: 19),
            label: const Text('Locate on Guide Map'),
          )
        : null;

    final secondaryButton = onViewDetails != null
        ? OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: wonderlaNavy,
              side: const BorderSide(color: wonderlaBorder, width: 1.4),
              minimumSize: const Size(48, 48),
            ),
            onPressed: onViewDetails,
            icon: Icon(
              item.isDining
                  ? Icons.restaurant_menu_rounded
                  : Icons.open_in_new_rounded,
              size: 18,
            ),
            label: Text(
              viewDetailsLabel ??
                  (item.isDining ? 'View Menu' : 'View Details'),
            ),
          )
        : null;

    if (primaryButton == null && secondaryButton == null) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (primaryButton != null && secondaryButton != null) {
          if (constraints.maxWidth < 360) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                primaryButton,
                const SizedBox(height: 10),
                secondaryButton,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: primaryButton),
              const SizedBox(width: 10),
              Expanded(child: secondaryButton),
            ],
          );
        }
        return SizedBox(
          width: double.infinity,
          child: primaryButton ?? secondaryButton,
        );
      },
    );
  }
}
