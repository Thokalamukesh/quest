import 'package:flutter/material.dart';

import '../../../shared/wonderla_palette.dart';
import '../models/park_discovery_item.dart';
import 'park_map_marker.dart';

/// Controller for programmatic zoom, pan-to-place, and reset on the
/// illustrated Wonderla park guide map.
class IllustratedParkMapController {
  VoidCallback? _onReset;
  VoidCallback? _onZoomIn;
  VoidCallback? _onZoomOut;
  void Function(double xPercent, double yPercent)? _onFocusPercent;

  void reset() => _onReset?.call();
  void zoomIn() => _onZoomIn?.call();
  void zoomOut() => _onZoomOut?.call();
  void focusPercent(double xPercent, double yPercent) =>
      _onFocusPercent?.call(xPercent, yPercent);

  void _attach({
    required VoidCallback onReset,
    required VoidCallback onZoomIn,
    required VoidCallback onZoomOut,
    required void Function(double, double) onFocusPercent,
  }) {
    _onReset = onReset;
    _onZoomIn = onZoomIn;
    _onZoomOut = onZoomOut;
    _onFocusPercent = onFocusPercent;
  }

  void _detach() {
    _onReset = null;
    _onZoomIn = null;
    _onZoomOut = null;
    _onFocusPercent = null;
  }
}

/// Interactive illustrated park map backed by the CMS `parkMap.img` artwork
/// and verified `x`/`y` percent marker coordinates. Smooth pinch-to-zoom and
/// pan without reloading the artwork when filters change.
class IllustratedParkMapView extends StatefulWidget {
  const IllustratedParkMapView({
    super.key,
    required this.imageUrl,
    required this.items,
    required this.onSelectItem,
    this.selectedItemId,
    this.controller,
  });

  final String imageUrl;
  final List<ParkDiscoveryItem> items;
  final String? selectedItemId;
  final ValueChanged<ParkDiscoveryItem> onSelectItem;
  final IllustratedParkMapController? controller;

  @override
  State<IllustratedParkMapView> createState() => _IllustratedParkMapViewState();
}

class _IllustratedParkMapViewState extends State<IllustratedParkMapView>
    with SingleTickerProviderStateMixin {
  final _transformController = TransformationController();
  late final AnimationController _animController;
  Animation<Matrix4>? _matrixAnimation;
  double _currentScale = 1.0;
  Size _viewportSize = Size.zero;

  static const _minScale = 1.0;
  static const _maxScale = 4.2;

  @override
  void initState() {
    super.initState();
    _animController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 280),
        )..addListener(() {
          if (_matrixAnimation != null) {
            _transformController.value = _matrixAnimation!.value;
          }
        });
    _transformController.addListener(_onTransformChanged);
    _attachController();
  }

  @override
  void didUpdateWidget(covariant IllustratedParkMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      _attachController();
    }
  }

  void _attachController() {
    widget.controller?._attach(
      onReset: _resetView,
      onZoomIn: () => _scaleBy(1.35),
      onZoomOut: () => _scaleBy(0.74),
      onFocusPercent: _focusPercent,
    );
  }

  void _onTransformChanged() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    final crossedThreshold =
        (_currentScale < 1.65 && scale >= 1.65) ||
        (_currentScale >= 1.65 && scale < 1.65);
    _currentScale = scale;
    if (crossedThreshold && mounted) {
      setState(() {});
    }
  }

  void _animateTo(Matrix4 target) {
    _matrixAnimation = Matrix4Tween(
      begin: _transformController.value,
      end: target,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward(from: 0);
  }

  void _resetView() {
    _animateTo(Matrix4.identity());
  }

  void _scaleBy(double factor) {
    final current = _transformController.value;
    final currentScale = current.getMaxScaleOnAxis();
    final nextScale = (currentScale * factor).clamp(_minScale, _maxScale);
    if ((nextScale - currentScale).abs() < 0.01) return;
    final focalX = _viewportSize.width / 2;
    final focalY = _viewportSize.height / 2;
    final ratio = nextScale / currentScale;
    final tx = focalX - (focalX - current.storage[12]) * ratio;
    final ty = focalY - (focalY - current.storage[13]) * ratio;
    final target = Matrix4.identity()
      ..setEntry(0, 0, nextScale)
      ..setEntry(1, 1, nextScale)
      ..setEntry(2, 2, 1.0)
      ..setEntry(0, 3, _clampTranslation(tx, _viewportSize.width, nextScale))
      ..setEntry(1, 3, _clampTranslation(ty, _viewportSize.height, nextScale));
    _animateTo(target);
  }

  void _focusPercent(double xPercent, double yPercent) {
    if (_viewportSize.isEmpty) return;
    const targetScale = 2.2;
    final px = (xPercent.clamp(0.0, 100.0) / 100.0) * _viewportSize.width;
    final py = (yPercent.clamp(0.0, 100.0) / 100.0) * _viewportSize.height;
    final tx = _viewportSize.width / 2 - px * targetScale;
    final ty = _viewportSize.height * 0.44 - py * targetScale;
    final target = Matrix4.identity()
      ..setEntry(0, 0, targetScale)
      ..setEntry(1, 1, targetScale)
      ..setEntry(2, 2, 1.0)
      ..setEntry(0, 3, _clampTranslation(tx, _viewportSize.width, targetScale))
      ..setEntry(1, 3, _clampTranslation(ty, _viewportSize.height, targetScale));
    _animateTo(target);
  }

  double _clampTranslation(double value, double viewportExtent, double scale) {
    final minTranslate = viewportExtent - viewportExtent * scale;
    return value.clamp(minTranslate, 0.0);
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mappedItems = widget.items
        .where((item) => item.hasIllustratedCoords)
        .toList(growable: false);
    final showLabels = _currentScale >= 1.65 || mappedItems.length <= 6;

    return Container(
      color: const Color(0xFFE7EEF6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          _viewportSize = constraints.biggest;
          return InteractiveViewer(
            transformationController: _transformController,
            minScale: _minScale,
            maxScale: _maxScale,
            boundaryMargin: const EdgeInsets.all(24),
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    widget.imageUrl,
                    key: ValueKey(widget.imageUrl),
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              color: wonderlaCobalt,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Loading park guide artwork…',
                              style: TextStyle(
                                color: wonderlaNavy.withValues(alpha: .8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    errorBuilder: (_, _, _) => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.broken_image_outlined,
                              color: wonderlaMuted,
                              size: 42,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Illustrated park map could not load.\nSwitch to Live GPS Map to continue exploring.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: wonderlaNavy),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  for (final item in mappedItems)
                    Positioned(
                      left:
                          (item.mapX!.clamp(0.0, 100.0) / 100.0) *
                              constraints.maxWidth -
                          56,
                      top:
                          (item.mapY!.clamp(0.0, 100.0) / 100.0) *
                              constraints.maxHeight -
                          44,
                      width: 112,
                      child: Center(
                        child: WonderlaMapPin(
                          item: item,
                          selected: item.id == widget.selectedItemId,
                          showLabel: showLabels,
                          onTap: () {
                            _focusPercent(item.mapX!, item.mapY!);
                            widget.onSelectItem(item);
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
