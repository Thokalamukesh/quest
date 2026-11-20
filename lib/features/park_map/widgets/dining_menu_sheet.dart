import 'package:flutter/material.dart';

import '../../../shared/wonderla_palette.dart';

/// Opens the interactive Veg / Non-Veg restaurant menu bottom sheet for a
/// Wonderla dining outlet. Shared between the Dining screen and Park Map.
Future<void> showWonderlaDiningMenuSheet(
  BuildContext context, {
  required Map<String, dynamic> outlet,
  required String Function(String? path) resolveUrl,
  VoidCallback? onLocateOnMap,
}) {
  var menuFilter = 'All';
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) {
      final all = List<Map<String, dynamic>>.from(
        (outlet['items'] as List? ?? const []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
      final rawTags = outlet['tags'] is List
          ? (outlet['tags'] as List).map((e) => e.toString()).toList()
          : const <String>[];

      return StatefulBuilder(
        builder: (ctx, localSet) {
          final filtered = all
              .where(
                (it) =>
                    menuFilter == 'All' ||
                    (menuFilter == 'Veg' ? it['veg'] == true : it['veg'] != true),
              )
              .toList(growable: false);

          return SafeArea(
            child: FractionallySizedBox(
              heightFactor: 0.90,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [wonderlaNavy, wonderlaCobalt],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
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
                                  if ((outlet['cuisine']?.toString() ?? '')
                                      .isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: wonderlaGold,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Text(
                                        outlet['cuisine'].toString(),
                                        style: const TextStyle(
                                          color: wonderlaNavy,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  Text(
                                    '${outlet['name'] ?? 'Dining'}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      height: 1.15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (onLocateOnMap != null)
                              FilledButton.tonalIcon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(
                                    alpha: .16,
                                  ),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(0, 38),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  onLocateOnMap();
                                },
                                icon: const Icon(
                                  Icons.map_rounded,
                                  size: 16,
                                  color: wonderlaGold,
                                ),
                                label: const Text(
                                  'Map',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                          ],
                        ),
                        if ((outlet['description']?.toString() ?? '')
                            .isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            outlet['description'].toString(),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .9),
                              height: 1.4,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                        if (rawTags.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final tag in rawTags)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: .15),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    tag,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      children: [
                        const Text(
                          'Menu',
                          style: TextStyle(
                            color: wonderlaNavy,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        Wrap(
                          spacing: 6,
                          children: [
                            for (final f in const ['All', 'Veg', 'Non-Veg'])
                              ChoiceChip(
                                label: Text(f),
                                selected: menuFilter == f,
                                showCheckmark: false,
                                selectedColor: f == 'Veg'
                                    ? wonderlaSuccess
                                    : f == 'Non-Veg'
                                    ? wonderlaFlagRed
                                    : wonderlaNavy,
                                backgroundColor: wonderlaCream,
                                side: BorderSide.none,
                                labelStyle: TextStyle(
                                  color: menuFilter == f
                                      ? Colors.white
                                      : wonderlaNavy,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                                onSelected: (_) =>
                                    localSet(() => menuFilter = f),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'No menu items match this filter.',
                                style: TextStyle(
                                  color: wonderlaMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 9),
                            itemBuilder: (_, index) {
                              final item = filtered[index];
                              final veg = item['veg'] == true;
                              final imgPath = resolveUrl(
                                item['img']?.toString(),
                              );
                              return Container(
                                padding: const EdgeInsets.all(11),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: wonderlaBorder),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(13),
                                      child: SizedBox(
                                        width: 54,
                                        height: 54,
                                        child: imgPath.isEmpty
                                            ? Container(
                                                color: wonderlaCream,
                                                alignment: Alignment.center,
                                                child: Icon(
                                                  Icons.restaurant_rounded,
                                                  color: veg
                                                      ? wonderlaSuccess
                                                      : wonderlaFlagRed,
                                                  size: 22,
                                                ),
                                              )
                                            : Image.network(
                                                imgPath,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) =>
                                                    Container(
                                                      color: wonderlaCream,
                                                      alignment:
                                                          Alignment.center,
                                                      child: const Icon(
                                                        Icons
                                                            .restaurant_rounded,
                                                        color: wonderlaCobalt,
                                                        size: 22,
                                                      ),
                                                    ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['name']?.toString() ?? '',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: wonderlaNavy,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14.5,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: veg
                                                      ? wonderlaSuccess
                                                      : wonderlaFlagRed,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                veg
                                                    ? 'Vegetarian'
                                                    : 'Non-vegetarian',
                                                style: const TextStyle(
                                                  color: wonderlaMuted,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      item['price']?.toString() ?? '',
                                      style: const TextStyle(
                                        color: wonderlaNavy,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
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
