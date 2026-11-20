import 'package:flutter/material.dart';

import '../../../shared/wonderla_palette.dart';
import '../models/park_discovery_item.dart';

/// Color-codes a real wait time (minutes) using clear theme-park crowd levels.
Color wonderlaWaitTimeColor(int minutes) {
  if (minutes <= 10) return wonderlaSuccess;
  if (minutes < 25) return wonderlaWarning;
  return wonderlaFlagRed;
}

String wonderlaWaitTimeCrowdLabel(int minutes) {
  if (minutes <= 10) return 'Short wait';
  if (minutes < 25) return 'Moderate';
  return 'Busy';
}

/// Custom Wonderla map marker with category-specific shapes, icons,
/// optional live wait-time micro-badge, and smart name pill.
class WonderlaMapPin extends StatelessWidget {
  const WonderlaMapPin({
    super.key,
    required this.item,
    required this.selected,
    required this.showLabel,
    required this.onTap,
  });

  final ParkDiscoveryItem item;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final category = item.category;
    final isDiningPin =
        category == ParkDiscoveryCategory.restaurants ||
        category == ParkDiscoveryCategory.foodAndBeverages;
    final isUtilityPin =
        category == ParkDiscoveryCategory.facilities ||
        category == ParkDiscoveryCategory.restrooms;

    final pinColor = selected ? wonderlaGold : category.color;
    final iconColor = selected
        ? wonderlaNavy
        : isUtilityPin
        ? category.color
        : Colors.white;
    final fillColor = selected
        ? wonderlaGold
        : isUtilityPin
        ? Colors.white
        : category.color;
    final borderColor = selected
        ? wonderlaNavy
        : isUtilityPin
        ? category.color
        : Colors.white;

    final badgeSize = selected ? 42.0 : 34.0;
    final borderRadius = isDiningPin
        ? BorderRadius.circular(12)
        : isUtilityPin
        ? BorderRadius.circular(10)
        : BorderRadius.circular(badgeSize / 2);

    return Semantics(
      button: true,
      selected: selected,
      label: item.waitTimeMinutes != null
          ? '${item.name}, ${item.category.label}, ${item.waitTimeMinutes} minute wait'
          : '${item.name}, ${item.category.label}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: selected ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  if (selected)
                    Container(
                      width: badgeSize + 12,
                      height: badgeSize + 12,
                      decoration: BoxDecoration(
                        color: wonderlaGold.withValues(alpha: .32),
                        borderRadius: isDiningPin || isUtilityPin
                            ? BorderRadius.circular(16)
                            : BorderRadius.circular((badgeSize + 12) / 2),
                      ),
                    ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: badgeSize,
                        height: badgeSize,
                        decoration: BoxDecoration(
                          color: fillColor,
                          borderRadius: borderRadius,
                          border: Border.all(
                            color: borderColor,
                            width: selected ? 2.6 : 2.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: wonderlaNavy.withValues(
                                alpha: selected ? .32 : .24,
                              ),
                              blurRadius: selected ? 10 : 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          item.icon,
                          color: iconColor,
                          size: selected ? 20 : 17,
                        ),
                      ),
                      CustomPaint(
                        size: const Size(12, 7),
                        painter: _PinPointerPainter(
                          color: selected ? wonderlaNavy : pinColor,
                        ),
                      ),
                    ],
                  ),
                  if (item.waitTimeMinutes != null)
                    Positioned(
                      top: -7,
                      right: -12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: wonderlaWaitTimeColor(item.waitTimeMinutes!),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33102454),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          '${item.waitTimeMinutes}m',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (showLabel || selected) ...[
              const SizedBox(height: 2),
              Container(
                constraints: const BoxConstraints(maxWidth: 112),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: selected ? wonderlaNavy : Colors.white.withValues(alpha: .96),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: selected
                        ? wonderlaGold
                        : wonderlaBorder.withValues(alpha: .9),
                    width: selected ? 1.2 : 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x24102454),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? Colors.white : wonderlaNavy,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PinPointerPainter extends CustomPainter {
  const _PinPointerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PinPointerPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Visitor live GPS marker with layered accuracy halo or optional mascot avatar.
class WonderlaUserLocationPin extends StatelessWidget {
  const WonderlaUserLocationPin({super.key, this.useMascot = false});

  final bool useMascot;

  @override
  Widget build(BuildContext context) {
    if (useMascot) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: wonderlaBlue.withValues(alpha: .18),
              shape: BoxShape.circle,
            ),
          ),
          Image.asset(
            'assets/images/chikku_happy.png',
            width: 38,
            height: 38,
            fit: BoxFit.contain,
          ),
        ],
      );
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: wonderlaBlue.withValues(alpha: .20),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: wonderlaBlue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x44102454),
                blurRadius: 7,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
