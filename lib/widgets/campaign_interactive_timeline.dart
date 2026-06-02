import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/compendium_entry.dart';
import '../models/session.dart';
import '../models/story_timeline_item.dart';
import '../utils/compendium_linking.dart';
import 'compendium_mention_chips.dart';
import 'linked_compendium_text.dart';

class CampaignInteractiveTimeline extends StatefulWidget {
  final List<StoryTimelineItem> items;
  final List<CompendiumEntry> compendiumEntries;
  final void Function(DateTime date) onOpenDay;
  final ValueChanged<Session> onOpenSession;

  const CampaignInteractiveTimeline({
    super.key,
    required this.items,
    required this.compendiumEntries,
    required this.onOpenDay,
    required this.onOpenSession,
  });

  @override
  State<CampaignInteractiveTimeline> createState() =>
      _CampaignInteractiveTimelineState();
}

class _CampaignInteractiveTimelineState
    extends State<CampaignInteractiveTimeline> {
  static const double _nodeGap = 188;
  static const double _railPadding = 76;

  final ScrollController _scrollController = ScrollController();
  String? _selectedItemId;
  String _selectedMentionType = 'all';
  String? _focusedEntryId;
  double _zoom = 1.0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CampaignInteractiveTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sortedItems = _sortedItems;
    if (sortedItems.isEmpty) {
      _selectedItemId = null;
      return;
    }

    final selectedStillExists =
        sortedItems.any((item) => item.id == _selectedItemId);
    if (!selectedStillExists) {
      _selectedItemId = sortedItems.first.id;
    }
  }

  List<StoryTimelineItem> get _sortedItems {
    return [...widget.items]..sort((a, b) => a.date.compareTo(b.date));
  }

  double get _effectiveNodeGap => _nodeGap * _zoom;

  @override
  Widget build(BuildContext context) {
    final sortedItems = _sortedItems;
    if (sortedItems.isEmpty) return const SizedBox.shrink();

    final focusedEntry = _focusedEntry();
    final selectedItem = _selectedItem(sortedItems);
    final selectedIndex = sortedItems.indexWhere(
      (item) => item.id == selectedItem.id,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 860;
        final railHeight = isWide ? 352.0 : 324.0;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TimelineHeader(
                count: sortedItems.length,
                selectedIndex: selectedIndex,
                onPrevious: selectedIndex <= 0
                    ? null
                    : () => _selectIndex(sortedItems, selectedIndex - 1),
                onNext: selectedIndex >= sortedItems.length - 1
                    ? null
                    : () => _selectIndex(sortedItems, selectedIndex + 1),
              ),
              const SizedBox(height: 14),
              _TimelineControls(
                zoom: _zoom,
                selectedMentionType: _selectedMentionType,
                focusedEntry: focusedEntry,
                focusedMatchCount: focusedEntry == null
                    ? 0
                    : _matchingIndexesForEntry(sortedItems, focusedEntry)
                        .length,
                typeCounts: _mentionTypeCounts(sortedItems),
                onZoomChanged: (value) {
                  setState(() {
                    _zoom = value;
                  });
                  _centerIndex(selectedIndex);
                },
                onMentionTypeChanged: (value) {
                  setState(() {
                    _selectedMentionType = value;
                  });
                },
                onClearFocus: focusedEntry == null
                    ? null
                    : () {
                        setState(() {
                          _focusedEntryId = null;
                          _selectedMentionType = 'all';
                        });
                      },
                onPreviousFocus: focusedEntry == null
                    ? null
                    : () => _focusAdjacentEntryOccurrence(
                          sortedItems,
                          focusedEntry,
                          -1,
                        ),
                onNextFocus: focusedEntry == null
                    ? null
                    : () => _focusAdjacentEntryOccurrence(
                          sortedItems,
                          focusedEntry,
                          1,
                        ),
              ),
              const SizedBox(height: 14),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: _buildRail(
                        context,
                        items: sortedItems,
                        selectedItem: selectedItem,
                        focusedEntry: focusedEntry,
                        viewportWidth: constraints.maxWidth * 0.62,
                        height: railHeight,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 4,
                      child: _TimelineInspector(
                        item: selectedItem,
                        compendiumEntries: widget.compendiumEntries,
                        onMentionPressed: (entry) =>
                            _focusEntry(sortedItems, entry),
                        onOpenDay: () => widget.onOpenDay(selectedItem.date),
                        onOpenSession: selectedItem.linkedSession == null
                            ? null
                            : () => widget.onOpenSession(
                                  selectedItem.linkedSession!,
                                ),
                      ),
                    ),
                  ],
                )
              else ...[
                _buildRail(
                  context,
                  items: sortedItems,
                  selectedItem: selectedItem,
                  focusedEntry: focusedEntry,
                  viewportWidth: constraints.maxWidth,
                  height: railHeight,
                ),
                const SizedBox(height: 14),
                _TimelineInspector(
                  item: selectedItem,
                  compendiumEntries: widget.compendiumEntries,
                  onMentionPressed: (entry) => _focusEntry(sortedItems, entry),
                  onOpenDay: () => widget.onOpenDay(selectedItem.date),
                  onOpenSession: selectedItem.linkedSession == null
                      ? null
                      : () => widget.onOpenSession(selectedItem.linkedSession!),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRail(
    BuildContext context, {
    required List<StoryTimelineItem> items,
    required StoryTimelineItem selectedItem,
    required CompendiumEntry? focusedEntry,
    required double viewportWidth,
    required double height,
  }) {
    final nodeGap = _effectiveNodeGap;
    final contentWidth = math.max(
      viewportWidth,
      _railPadding * 2 + (items.length - 1) * nodeGap + 176,
    );
    final axisY = height / 2;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: height,
        color: Theme.of(context).colorScheme.surface,
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: contentWidth,
              height: height,
              child: Stack(
                children: [
                  Positioned(
                    left: 38,
                    right: 38,
                    top: axisY - 1,
                    child: Container(
                      height: 2,
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                  Positioned(
                    left: 38,
                    top: axisY - 16,
                    child: _AxisCap(
                      icon: Icons.flag_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Positioned(
                    right: 38,
                    top: axisY - 16,
                    child: _AxisCap(
                      icon: Icons.outlined_flag,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                  ),
                  for (var index = 0; index < items.length; index++)
                    _PositionedTimelineNode(
                      item: items[index],
                      index: index,
                      x: _railPadding + index * nodeGap,
                      axisY: axisY,
                      isSelected: items[index].id == selectedItem.id,
                      isFocusedMatch:
                          _matchesFocusedEntry(items[index], focusedEntry),
                      isDimmed: !_matchesTypeFilter(
                            items[index],
                            _selectedMentionType,
                          ) ||
                          (focusedEntry != null &&
                              !_matchesFocusedEntry(
                                  items[index], focusedEntry)),
                      compendiumEntries: widget.compendiumEntries,
                      onTap: () => _selectIndex(items, index),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  StoryTimelineItem _selectedItem(List<StoryTimelineItem> items) {
    final selectedId = _selectedItemId;
    if (selectedId != null) {
      for (final item in items) {
        if (item.id == selectedId) return item;
      }
    }

    return items.first;
  }

  void _selectIndex(List<StoryTimelineItem> items, int index) {
    if (index < 0 || index >= items.length) return;

    setState(() {
      _selectedItemId = items[index].id;
    });

    _centerIndex(index);
  }

  void _centerIndex(int index) {
    if (!_scrollController.hasClients) return;

    final targetOffset = math.max(
      0.0,
      index * _effectiveNodeGap - _effectiveNodeGap,
    );
    final boundedOffset = targetOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      boundedOffset,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _focusEntry(List<StoryTimelineItem> items, CompendiumEntry entry) {
    final matches = _matchingIndexesForEntry(items, entry);
    setState(() {
      _focusedEntryId = entry.id;
      _selectedMentionType = entry.type;
      if (matches.isNotEmpty) {
        _selectedItemId = items[matches.first].id;
      }
    });

    if (matches.isNotEmpty) {
      _centerIndex(matches.first);
    }
  }

  void _focusAdjacentEntryOccurrence(
    List<StoryTimelineItem> items,
    CompendiumEntry entry,
    int direction,
  ) {
    final matches = _matchingIndexesForEntry(items, entry);
    if (matches.isEmpty) return;

    final selectedId = _selectedItemId;
    final selectedIndex = items.indexWhere((item) => item.id == selectedId);
    int targetIndex;

    if (direction > 0) {
      targetIndex = matches.firstWhere(
        (index) => index > selectedIndex,
        orElse: () => matches.first,
      );
    } else {
      targetIndex = matches.lastWhere(
        (index) => index < selectedIndex,
        orElse: () => matches.last,
      );
    }

    _selectIndex(items, targetIndex);
  }

  List<int> _matchingIndexesForEntry(
    List<StoryTimelineItem> items,
    CompendiumEntry entry,
  ) {
    final indexes = <int>[];
    for (var index = 0; index < items.length; index++) {
      if (_matchesFocusedEntry(items[index], entry)) {
        indexes.add(index);
      }
    }
    return indexes;
  }

  bool _matchesFocusedEntry(StoryTimelineItem item, CompendiumEntry? entry) {
    if (entry == null) return false;
    return CompendiumLinking.mentionedEntries(
      text: item.linkText,
      entries: widget.compendiumEntries,
    ).any((mentionedEntry) => mentionedEntry.id == entry.id);
  }

  bool _matchesTypeFilter(StoryTimelineItem item, String type) {
    if (type == 'all') return true;
    return CompendiumLinking.mentionedEntries(
      text: item.linkText,
      entries: widget.compendiumEntries,
    ).any((entry) => entry.type == type);
  }

  Map<String, int> _mentionTypeCounts(List<StoryTimelineItem> items) {
    const types = ['npc', 'location', 'item', 'faction', 'lore'];
    return {
      for (final type in types)
        type: items.where((item) => _matchesTypeFilter(item, type)).length,
    };
  }

  CompendiumEntry? _focusedEntry() {
    final focusedId = _focusedEntryId;
    if (focusedId == null) return null;
    for (final entry in widget.compendiumEntries) {
      if (entry.id == focusedId) return entry;
    }
    return null;
  }
}

class _TimelineHeader extends StatelessWidget {
  final int count;
  final int selectedIndex;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _TimelineHeader({
    required this.count,
    required this.selectedIndex,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.timeline_outlined),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Storyline',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '${selectedIndex + 1} / $count',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous',
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next',
        ),
      ],
    );
  }
}

class _TimelineControls extends StatelessWidget {
  final double zoom;
  final String selectedMentionType;
  final CompendiumEntry? focusedEntry;
  final int focusedMatchCount;
  final Map<String, int> typeCounts;
  final ValueChanged<double> onZoomChanged;
  final ValueChanged<String> onMentionTypeChanged;
  final VoidCallback? onClearFocus;
  final VoidCallback? onPreviousFocus;
  final VoidCallback? onNextFocus;

  const _TimelineControls({
    required this.zoom,
    required this.selectedMentionType,
    required this.focusedEntry,
    required this.focusedMatchCount,
    required this.typeCounts,
    required this.onZoomChanged,
    required this.onMentionTypeChanged,
    required this.onClearFocus,
    required this.onPreviousFocus,
    required this.onNextFocus,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ZoomControl(
          zoom: zoom,
          onChanged: onZoomChanged,
        ),
        const SizedBox(height: 10),
        _MentionTypeFilter(
          selectedType: selectedMentionType,
          counts: typeCounts,
          onChanged: onMentionTypeChanged,
        ),
        if (focusedEntry != null) ...[
          const SizedBox(height: 12),
          _FocusedEntryBar(
            entry: focusedEntry!,
            matchCount: focusedMatchCount,
            onPrevious: onPreviousFocus,
            onNext: onNextFocus,
            onClear: onClearFocus,
          ),
        ],
      ],
    );
  }
}

class _ZoomControl extends StatelessWidget {
  final double zoom;
  final ValueChanged<double> onChanged;

  const _ZoomControl({
    required this.zoom,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.zoom_out, size: 18),
          Expanded(
            child: Slider(
              value: zoom,
              min: 0.92,
              max: 1.36,
              divisions: 4,
              label: '${(zoom * 100).round()}%',
              onChanged: onChanged,
            ),
          ),
          const Icon(Icons.zoom_in, size: 18),
        ],
      ),
    );
  }
}

class _MentionTypeFilter extends StatelessWidget {
  final String selectedType;
  final Map<String, int> counts;
  final ValueChanged<String> onChanged;

  const _MentionTypeFilter({
    required this.selectedType,
    required this.counts,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final types = [
      const _MentionTypeOption(
        value: 'all',
        label: 'All',
        icon: Icons.all_inclusive,
      ),
      _MentionTypeOption(
        value: 'npc',
        label: 'NPC',
        icon: Icons.person_outline,
        count: counts['npc'] ?? 0,
      ),
      _MentionTypeOption(
        value: 'location',
        label: 'Places',
        icon: Icons.place_outlined,
        count: counts['location'] ?? 0,
      ),
      _MentionTypeOption(
        value: 'item',
        label: 'Items',
        icon: Icons.inventory_2_outlined,
        count: counts['item'] ?? 0,
      ),
      _MentionTypeOption(
        value: 'faction',
        label: 'Factions',
        icon: Icons.shield_outlined,
        count: counts['faction'] ?? 0,
      ),
      _MentionTypeOption(
        value: 'lore',
        label: 'Lore',
        icon: Icons.auto_stories_outlined,
        count: counts['lore'] ?? 0,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: types.map((type) {
          final isSelected = selectedType == type.value;
          final label =
              type.count == null ? type.label : '${type.label} ${type.count}';

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: isSelected,
              avatar: Icon(type.icon, size: 16),
              label: Text(label),
              onSelected: (_) => onChanged(type.value),
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FocusedEntryBar extends StatelessWidget {
  final CompendiumEntry entry;
  final int matchCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onClear;

  const _FocusedEntryBar({
    required this.entry,
    required this.matchCount,
    required this.onPrevious,
    required this.onNext,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          Icon(_iconForEntryType(entry.type), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${entry.title} appears in $matchCount beat${matchCount == 1 ? '' : 's'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous mention',
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next mention',
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close),
            tooltip: 'Clear focus',
          ),
        ],
      ),
    );
  }
}

class _MentionTypeOption {
  final String value;
  final String label;
  final IconData icon;
  final int? count;

  const _MentionTypeOption({
    required this.value,
    required this.label,
    required this.icon,
    this.count,
  });
}

class _PositionedTimelineNode extends StatelessWidget {
  final StoryTimelineItem item;
  final int index;
  final double x;
  final double axisY;
  final bool isSelected;
  final bool isFocusedMatch;
  final bool isDimmed;
  final List<CompendiumEntry> compendiumEntries;
  final VoidCallback onTap;

  const _PositionedTimelineNode({
    required this.item,
    required this.index,
    required this.x,
    required this.axisY,
    required this.isSelected,
    required this.isFocusedMatch,
    required this.isDimmed,
    required this.compendiumEntries,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isTop = index.isEven;
    final cardTop = isTop ? axisY - 146 : axisY + 44;
    final color = _colorForItem(context, item);

    return Stack(
      children: [
        Positioned(
          left: x + 8,
          top: isTop ? axisY - 42 : axisY + 20,
          child: Container(
            width: 2,
            height: 26,
            color: color.withValues(alpha: isSelected ? 0.85 : 0.36),
          ),
        ),
        Positioned(
          left: x - 17,
          top: axisY - 17,
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected || isFocusedMatch
                    ? color
                    : Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDimmed ? Theme.of(context).dividerColor : color,
                  width: isSelected ? 4 : 2,
                ),
                boxShadow: isSelected || isFocusedMatch
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.28),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                _iconForItem(item),
                size: 17,
                color: isSelected || isFocusedMatch
                    ? Theme.of(context).colorScheme.onPrimary
                    : (isDimmed ? Theme.of(context).disabledColor : color),
              ),
            ),
          ),
        ),
        Positioned(
          left: x - 82,
          top: cardTop,
          child: _TimelineNodeCard(
            item: item,
            color: color,
            isSelected: isSelected,
            isFocusedMatch: isFocusedMatch,
            isDimmed: isDimmed,
            compendiumEntries: compendiumEntries,
            onTap: onTap,
          ),
        ),
      ],
    );
  }
}

class _TimelineNodeCard extends StatelessWidget {
  final StoryTimelineItem item;
  final Color color;
  final bool isSelected;
  final bool isFocusedMatch;
  final bool isDimmed;
  final List<CompendiumEntry> compendiumEntries;
  final VoidCallback onTap;

  const _TimelineNodeCard({
    required this.item,
    required this.color,
    required this.isSelected,
    required this.isFocusedMatch,
    required this.isDimmed,
    required this.compendiumEntries,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final mentionCount = CompendiumLinking.mentionedEntries(
      text: item.linkText,
      entries: compendiumEntries,
    ).length;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 166,
        height: 104,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: isSelected || isFocusedMatch
              ? color.withValues(alpha: 0.12)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected || isFocusedMatch
                ? color
                : Theme.of(context).dividerColor,
            width: isSelected || isFocusedMatch ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _iconForItem(item),
                  size: 15,
                  color: isDimmed ? Theme.of(context).disabledColor : color,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    _kindLabel(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: isDimmed ? Theme.of(context).disabledColor : null,
                  ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatShortDate(item.date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                if (mentionCount > 0) ...[
                  const Icon(Icons.link, size: 13),
                  const SizedBox(width: 3),
                  Text(
                    mentionCount.toString(),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineInspector extends StatelessWidget {
  final StoryTimelineItem item;
  final List<CompendiumEntry> compendiumEntries;
  final ValueChanged<CompendiumEntry> onMentionPressed;
  final VoidCallback onOpenDay;
  final VoidCallback? onOpenSession;

  const _TimelineInspector({
    required this.item,
    required this.compendiumEntries,
    required this.onMentionPressed,
    required this.onOpenDay,
    required this.onOpenSession,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorForItem(context, item);
    final mentionedEntries = CompendiumLinking.mentionedEntries(
      text: item.linkText,
      entries: compendiumEntries,
    );

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 324),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconForItem(item), color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(_kindLabel(item)),
                          visualDensity: VisualDensity.compact,
                        ),
                        Chip(
                          label: Text(_formatDateTime(item.date)),
                          visualDensity: VisualDensity.compact,
                        ),
                        if (item.author != null)
                          Chip(
                            label: Text(item.author!),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (item.body.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: LinkedCompendiumText(
                text: item.body,
                campaignId: item.campaignId,
                maxLines: 7,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (mentionedEntries.isNotEmpty) ...[
            const SizedBox(height: 12),
            CompendiumMentionChips(
              text: item.linkText,
              campaignId: item.campaignId,
              maxItems: 6,
              onEntryPressed: onMentionPressed,
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: onOpenDay,
                icon: const Icon(Icons.today_outlined),
                label: const Text('Open day'),
              ),
              if (onOpenSession != null)
                OutlinedButton.icon(
                  onPressed: onOpenSession,
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Open session'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AxisCap extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _AxisCap({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Icon(icon, size: 17, color: color),
    );
  }
}

Color _colorForItem(BuildContext context, StoryTimelineItem item) {
  if (item.kind == 'session') return Theme.of(context).colorScheme.primary;
  if (item.kind == 'note') return Theme.of(context).colorScheme.tertiary;

  switch (item.type) {
    case 'combat':
      return Colors.redAccent;
    case 'dialogue':
      return Colors.teal;
    case 'travel':
      return Colors.green;
    case 'quest':
      return Colors.amber.shade800;
    case 'rumor':
      return Colors.deepPurpleAccent;
    case 'discovery':
    default:
      return Colors.blueAccent;
  }
}

IconData _iconForItem(StoryTimelineItem item) {
  if (item.kind == 'note') return Icons.edit_note;
  if (item.kind == 'session') return Icons.auto_stories_outlined;

  switch (item.type) {
    case 'combat':
      return Icons.flash_on_outlined;
    case 'dialogue':
      return Icons.forum_outlined;
    case 'travel':
      return Icons.map_outlined;
    case 'quest':
      return Icons.assignment_outlined;
    case 'rumor':
      return Icons.campaign_outlined;
    case 'discovery':
    default:
      return Icons.visibility_outlined;
  }
}

IconData _iconForEntryType(String type) {
  switch (type) {
    case 'location':
      return Icons.place_outlined;
    case 'item':
      return Icons.inventory_2_outlined;
    case 'faction':
      return Icons.shield_outlined;
    case 'lore':
      return Icons.auto_stories_outlined;
    case 'npc':
    default:
      return Icons.person_outline;
  }
}

String _kindLabel(StoryTimelineItem item) {
  if (item.kind == 'note') return item.isPrivate ? 'Private note' : 'Note';
  if (item.kind == 'event') return item.type ?? 'Event';
  return 'Session';
}

String _formatShortDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month';
}

String _formatDateTime(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$minute';
}
