import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import '../../../shared/wonderla_palette.dart';
import '../models/park_discovery_item.dart';

/// Floating rounded search header overlaid cleanly above the interactive map.
class ParkFloatingSearchHeader extends StatelessWidget {
  const ParkFloatingSearchHeader({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    this.focusNode,
    this.onBack,
    this.onSubmitted,
    this.onOpenFilters,
    this.activeFilterCount = 0,
    this.searching = false,
    this.hintText = 'Search rides, dining, facilities…',
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback? onBack;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onOpenFilters;
  final int activeFilterCount;
  final bool searching;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: wonderlaBorder.withValues(alpha: .9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1E102454),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              tooltip: 'Back',
              onPressed: onBack,
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: wonderlaNavy,
                size: 22,
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(left: 14, right: 6),
              child: Icon(Icons.search_rounded, color: wonderlaCobalt, size: 22),
            ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                color: wonderlaNavy,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(
                  color: wonderlaMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (searching)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: wonderlaCobalt,
                ),
              ),
            )
          else if (controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear search',
              onPressed: onClear,
              icon: const Icon(
                Icons.close_rounded,
                color: wonderlaMuted,
                size: 20,
              ),
            ),
          if (onOpenFilters != null) ...[
            Container(
              width: 1,
              height: 24,
              color: wonderlaBorder,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 6),
              child: InkWell(
                onTap: onOpenFilters,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 19,
                        color: activeFilterCount > 0
                            ? wonderlaCobalt
                            : wonderlaNavy,
                      ),
                      if (activeFilterCount > 0) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: wonderlaGold,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$activeFilterCount',
                            style: const TextStyle(
                              color: wonderlaNavy,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Horizontally scrollable multi-select category filter chips backed solely by
/// categories present in the park's real data, plus a Clear All action.
class ParkCategoryFilterBar extends StatelessWidget {
  const ParkCategoryFilterBar({
    super.key,
    required this.availableCategories,
    required this.categoryCounts,
    required this.selectedCategories,
    required this.onSelectAll,
    required this.onToggleCategory,
    required this.hasAnyActiveFilter,
    required this.onClearAll,
    this.totalCount,
    this.savedOnly = false,
    this.savedCount = 0,
    this.onToggleSavedOnly,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
  });

  final List<ParkDiscoveryCategory> availableCategories;
  final Map<ParkDiscoveryCategory, int> categoryCounts;
  final Set<ParkDiscoveryCategory> selectedCategories;
  final VoidCallback onSelectAll;
  final ValueChanged<ParkDiscoveryCategory> onToggleCategory;
  final bool hasAnyActiveFilter;
  final VoidCallback onClearAll;
  final int? totalCount;
  final bool savedOnly;
  final int savedCount;
  final VoidCallback? onToggleSavedOnly;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (availableCategories.isEmpty) return const SizedBox.shrink();
    final isAllSelected = selectedCategories.isEmpty && !savedOnly;

    return SizedBox(
      height: 39,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: const {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
          },
        ),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: padding,
          children: [
            _FilterPill(
              label: 'All',
              count: totalCount,
              icon: Icons.grid_view_rounded,
              selected: isAllSelected,
              activeColor: wonderlaNavy,
              iconTint: wonderlaCobalt,
              onTap: onSelectAll,
            ),
            const SizedBox(width: 7),
            if (hasAnyActiveFilter) ...[
              _ClearAllPill(onTap: onClearAll),
              const SizedBox(width: 7),
            ],
            if (onToggleSavedOnly != null && (savedCount > 0 || savedOnly)) ...[
              _FilterPill(
                label: 'Saved',
                count: savedCount,
                icon: savedOnly
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                selected: savedOnly,
                activeColor: wonderlaFlagRed,
                iconTint: wonderlaFlagRed,
                onTap: onToggleSavedOnly!,
              ),
              const SizedBox(width: 7),
            ],
            for (final category in availableCategories) ...[
              _FilterPill(
                label: category.label,
                count: categoryCounts[category],
                icon: category.icon,
                selected: selectedCategories.contains(category),
                activeColor: category.color,
                iconTint: category.color,
                onTap: () => onToggleCategory(category),
              ),
              const SizedBox(width: 7),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.activeColor,
    required this.iconTint,
    required this.onTap,
    this.count,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color activeColor;
  final Color iconTint;
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? activeColor : Colors.white.withValues(alpha: .97),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? activeColor : wonderlaBorder,
              width: selected ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: (selected ? activeColor : wonderlaNavy).withValues(
                  alpha: selected ? .26 : .12,
                ),
                blurRadius: selected ? 10 : 7,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : iconTint,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : wonderlaNavy,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (count != null && count! > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5.5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: .22)
                        : wonderlaCream,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: selected ? Colors.white : wonderlaMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ClearAllPill extends StatelessWidget {
  const _ClearAllPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: wonderlaGold.withValues(alpha: .95),
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F102454),
                blurRadius: 7,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.close_rounded, size: 15, color: wonderlaNavy),
              SizedBox(width: 4),
              Text(
                'Clear all',
                style: TextStyle(
                  color: wonderlaNavy,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Filter selection state returned by [showParkFilterSheet].
class ParkFilterSelection {
  const ParkFilterSelection({
    required this.categories,
    this.zoneName,
    this.shortWaitOnly = false,
    this.directionsReadyOnly = false,
    this.kioskBookingOnly = false,
    this.useIllustratedMap = false,
  });

  final Set<ParkDiscoveryCategory> categories;
  final String? zoneName;
  final bool shortWaitOnly;
  final bool directionsReadyOnly;
  final bool kioskBookingOnly;
  final bool useIllustratedMap;
}

/// Opens the optional Disneyland-inspired Wonderla filter bottom sheet.
Future<ParkFilterSelection?> showParkFilterSheet(
  BuildContext context, {
  required ParkDiscoveryCatalog catalog,
  required ParkFilterSelection initial,
  required String currentSearchQuery,
}) {
  return showModalBottomSheet<ParkFilterSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) {
      final selectedCategories = Set<ParkDiscoveryCategory>.from(
        initial.categories,
      );
      var selectedZone = initial.zoneName;
      var shortWaitOnly = initial.shortWaitOnly;
      var directionsReadyOnly = initial.directionsReadyOnly;
      var kioskBookingOnly = initial.kioskBookingOnly;
      var useIllustratedMap = initial.useIllustratedMap;

      return StatefulBuilder(
        builder: (context, setModalState) {
          final matchingCount = catalog
              .filter(
                query: currentSearchQuery,
                categories: selectedCategories,
                zoneName: selectedZone,
                shortWaitOnly: shortWaitOnly,
                directionsReadyOnly: directionsReadyOnly,
                kioskBookingOnly: kioskBookingOnly,
              )
              .length;

          final hasQuickRefines =
              catalog.hasAnyWaitTimes ||
              catalog.hasMixedCoordinates ||
              catalog.hasAnyKioskBooking;

          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.82,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Filter Park Map',
                                style: TextStyle(
                                  color: wonderlaNavy,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Refine rides, dining, and park services',
                                style: TextStyle(
                                  color: wonderlaMuted,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => setModalState(() {
                            selectedCategories.clear();
                            selectedZone = null;
                            shortWaitOnly = false;
                            directionsReadyOnly = false;
                            kioskBookingOnly = false;
                          }),
                          child: const Text(
                            'Reset all',
                            style: TextStyle(
                              color: wonderlaCobalt,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (catalog.hasIllustratedMap) ...[
                            const _SheetSectionTitle('Map Style'),
                            const SizedBox(height: 10),
                            SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment<bool>(
                                  value: false,
                                  icon: Icon(Icons.map_rounded, size: 18),
                                  label: Text('Live GPS Map'),
                                ),
                                ButtonSegment<bool>(
                                  value: true,
                                  icon: Icon(Icons.explore_rounded, size: 18),
                                  label: Text('Park Guide Map'),
                                ),
                              ],
                              selected: {useIllustratedMap},
                              onSelectionChanged: (selection) => setModalState(
                                () => useIllustratedMap = selection.first,
                              ),
                              style: ButtonStyle(
                                foregroundColor: WidgetStateProperty.resolveWith(
                                  (states) => states.contains(WidgetState.selected)
                                      ? Colors.white
                                      : wonderlaNavy,
                                ),
                                backgroundColor: WidgetStateProperty.resolveWith(
                                  (states) => states.contains(WidgetState.selected)
                                      ? wonderlaCobalt
                                      : wonderlaCream,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          const _SheetSectionTitle('Categories'),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 9,
                            children: [
                              for (final category in catalog.availableCategories)
                                _SheetCategoryChip(
                                  category: category,
                                  count: catalog.categoryCounts[category] ?? 0,
                                  selected: selectedCategories.contains(category),
                                  onTap: () => setModalState(() {
                                    if (!selectedCategories.add(category)) {
                                      selectedCategories.remove(category);
                                    }
                                  }),
                                ),
                            ],
                          ),
                          if (catalog.zones.isNotEmpty) ...[
                            const SizedBox(height: 22),
                            const _SheetSectionTitle('Park Zones'),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final zone in catalog.zones)
                                  ChoiceChip(
                                    label: Text(zone.name),
                                    selected: selectedZone == zone.name,
                                    showCheckmark: false,
                                    selectedColor: wonderlaNavy,
                                    backgroundColor: wonderlaCream,
                                    side: BorderSide(
                                      color: selectedZone == zone.name
                                          ? wonderlaNavy
                                          : wonderlaBorder,
                                    ),
                                    labelStyle: TextStyle(
                                      color: selectedZone == zone.name
                                          ? Colors.white
                                          : wonderlaNavy,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                    onSelected: (value) => setModalState(() {
                                      selectedZone = value ? zone.name : null;
                                    }),
                                  ),
                              ],
                            ),
                          ],
                          if (hasQuickRefines) ...[
                            const SizedBox(height: 22),
                            const _SheetSectionTitle('Quick Refine'),
                            const SizedBox(height: 8),
                            if (catalog.hasAnyWaitTimes)
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                activeTrackColor: wonderlaCobalt,
                                title: const Text(
                                  'Short wait time (15 min or less)',
                                  style: TextStyle(
                                    color: wonderlaNavy,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: const Text(
                                  'Show rides with short live queues',
                                  style: TextStyle(fontSize: 12),
                                ),
                                value: shortWaitOnly,
                                onChanged: (v) =>
                                    setModalState(() => shortWaitOnly = v),
                              ),
                            if (catalog.hasMixedCoordinates)
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                activeTrackColor: wonderlaCobalt,
                                title: const Text(
                                  'Walking directions ready',
                                  style: TextStyle(
                                    color: wonderlaNavy,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: const Text(
                                  'Only show places with live GPS coordinates',
                                  style: TextStyle(fontSize: 12),
                                ),
                                value: directionsReadyOnly,
                                onChanged: (v) =>
                                    setModalState(() => directionsReadyOnly = v),
                              ),
                            if (catalog.hasAnyKioskBooking)
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                activeTrackColor: wonderlaCobalt,
                                title: const Text(
                                  'Kiosk ride slot booking',
                                  style: TextStyle(
                                    color: wonderlaNavy,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: const Text(
                                  'Only show rides supporting park kiosk slots',
                                  style: TextStyle(fontSize: 12),
                                ),
                                value: kioskBookingOnly,
                                onChanged: (v) =>
                                    setModalState(() => kioskBookingOnly = v),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: wonderlaCobalt,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.of(context).pop(
                          ParkFilterSelection(
                            categories: selectedCategories,
                            zoneName: selectedZone,
                            shortWaitOnly: shortWaitOnly,
                            directionsReadyOnly: directionsReadyOnly,
                            kioskBookingOnly: kioskBookingOnly,
                            useIllustratedMap: useIllustratedMap,
                          ),
                        ),
                        child: Text(
                          'Show $matchingCount ${matchingCount == 1 ? 'place' : 'places'}',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _SheetSectionTitle extends StatelessWidget {
  const _SheetSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: wonderlaNavy,
        fontSize: 14,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.1,
      ),
    );
  }
}

class _SheetCategoryChip extends StatelessWidget {
  const _SheetCategoryChip({
    required this.category,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final ParkDiscoveryCategory category;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? category.color : category.tintColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? category.color
                : category.color.withValues(alpha: .28),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              category.icon,
              size: 16,
              color: selected ? Colors.white : category.color,
            ),
            const SizedBox(width: 6),
            Text(
              category.label,
              style: TextStyle(
                color: selected ? Colors.white : wonderlaNavy,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: .22)
                    : Colors.white.withValues(alpha: .8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: selected ? Colors.white : wonderlaNavy,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
