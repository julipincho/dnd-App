import 'package:flutter/material.dart';

import '../widgets/stitch_navigation.dart';

import '../models/dnd_class.dart';
import '../models/dnd_class_level.dart';
import '../services/class_level_service.dart';
import '../theme.dart';
import '../widgets/stitch_codex_ui.dart';

const Color _progressBg = StitchCodexPalette.ground;
const Color _progressAppBar = StitchCodexPalette.ground;
const Color _progressSurface = StitchCodexPalette.surfaceMuted;
const Color _progressSurfaceAlt = StitchCodexPalette.card;
const Color _progressHeader = StitchCodexPalette.surfaceRaised;
const Color _progressBorder = StitchCodexPalette.bronzeMuted;
const Color _progressBlue = StitchCodexPalette.bronze;

class ClassProgressionScreen extends StatefulWidget {
  final DndClass cls;

  const ClassProgressionScreen({
    super.key,
    required this.cls,
  });

  @override
  State<ClassProgressionScreen> createState() => _ClassProgressionScreenState();
}

class _ClassProgressionScreenState extends State<ClassProgressionScreen> {
  Map<int, DndClassLevel>? levels;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadLevels();
  }

  Future<void> _loadLevels() async {
    final data = await ClassLevelService.loadLevelsForClass(widget.cls.index);

    if (!mounted) return;

    setState(() {
      levels = data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasLevels = levels != null && levels!.isNotEmpty;

    return Scaffold(
      backgroundColor: _progressBg,
      appBar: StitchAppBar(
        showBrand: false,
        backgroundColor: _progressAppBar,
        elevation: 0,
        title: Text(
          '${widget.cls.name.toUpperCase()} PROGRESSION',
          style: const TextStyle(
            color: StitchCodexPalette.textPrimary,
            fontFamily: StitchTypography.display,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 8, 18, 18),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => Navigator.pop(context, widget.cls.index),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Continue'),
            style: stitchCodexPrimaryButtonStyle(),
          ),
        ),
      ),
      body: StitchCodexBackground(
        child: loading
            ? const Center(
                child: CircularProgressIndicator(color: _progressBlue),
              )
            : hasLevels
                ? _ProgressionTableView(
                    cls: widget.cls,
                    levels: levels!,
                  )
                : _NoLevelsMessage(className: widget.cls.name),
      ),
    );
  }
}

class _ProgressionTableView extends StatelessWidget {
  final DndClass cls;
  final Map<int, DndClassLevel> levels;

  const _ProgressionTableView({
    required this.cls,
    required this.levels,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = levels.values.toList()
      ..sort((a, b) => a.level.compareTo(b.level));
    final hasSpellcasting = sorted.any((level) => level.spellcasting != null);
    final hasSlots =
        sorted.any((level) => level.spellcasting?.hasSlots ?? false);
    final optionalColumnNames = _optionalColumnNames(sorted);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ClassTableHeader(
                  cls: cls,
                  levels: sorted,
                  hasSpellcasting: hasSpellcasting,
                ),
                const SizedBox(height: 16),
                _TableShell(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _ProgressionTable(
                      levels: sorted,
                      hasSpellcasting: hasSpellcasting,
                      hasSlots: hasSlots,
                      optionalColumnNames: optionalColumnNames,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<String> _optionalColumnNames(List<DndClassLevel> sorted) {
    final names = <String>{};
    for (final level in sorted) {
      names.addAll(level.optionalProgression.keys);
    }
    return names.toList()..sort();
  }
}

class _ClassTableHeader extends StatelessWidget {
  final DndClass cls;
  final List<DndClassLevel> levels;
  final bool hasSpellcasting;

  const _ClassTableHeader({
    required this.cls,
    required this.levels,
    required this.hasSpellcasting,
  });

  @override
  Widget build(BuildContext context) {
    final maxLevel = levels.isEmpty ? 0 : levels.last.level;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _progressSurface,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: _progressBorder.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The ${cls.name}',
            style: const TextStyle(
              color: StitchCodexPalette.textPrimary,
              fontFamily: StitchTypography.display,
              fontSize: 28,
              fontWeight: FontWeight.w600,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hasSpellcasting
                ? 'Class features, proficiency growth, and spellcasting in one table.'
                : 'Class features and proficiency growth in one table.',
            style: const TextStyle(
              color: StitchCodexPalette.textMuted,
              fontFamily: StitchTypography.body,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(label: 'Levels', value: '$maxLevel'),
              _InfoPill(label: 'Hit Die', value: 'd${cls.hitDie}'),
              if (cls.spellcastingAbility != null)
                _InfoPill(
                  label: 'Spellcasting',
                  value: cls.spellcastingAbility!,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final String value;

  const _InfoPill({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _progressBlue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: _progressBlue.withValues(alpha: 0.28),
        ),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: StitchCodexPalette.bronze,
          fontFamily: StitchTypography.data,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TableShell extends StatelessWidget {
  final Widget child;

  const _TableShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _progressSurface,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: _progressBorder.withValues(alpha: 0.60),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: child,
      ),
    );
  }
}

class _ProgressionTable extends StatelessWidget {
  final List<DndClassLevel> levels;
  final bool hasSpellcasting;
  final bool hasSlots;
  final List<String> optionalColumnNames;

  const _ProgressionTable({
    required this.levels,
    required this.hasSpellcasting,
    required this.hasSlots,
    required this.optionalColumnNames,
  });

  @override
  Widget build(BuildContext context) {
    final columns = _columns();
    final tableWidth =
        columns.fold<double>(0, (sum, column) => sum + column.width);

    return SizedBox(
      width: tableWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGroupedHeader(columns),
          _buildColumnHeader(columns),
          for (var index = 0; index < levels.length; index++)
            _buildDataRow(levels[index], columns, index),
        ],
      ),
    );
  }

  List<_ProgressionColumn> _columns() {
    return [
      _ProgressionColumn(
        key: 'level',
        label: 'Level',
        width: 78,
        align: TextAlign.center,
        value: (level) => _ordinal(level.level),
      ),
      _ProgressionColumn(
        key: 'prof',
        label: 'Prof. Bonus',
        width: 104,
        align: TextAlign.center,
        value: (level) => '+${level.profBonus}',
      ),
      _ProgressionColumn(
        key: 'features',
        label: 'Features',
        width: 360,
        value: (level) =>
            level.features.isEmpty ? '-' : level.features.join(', '),
      ),
      if (hasSpellcasting)
        _ProgressionColumn(
          key: 'cantrips',
          label: 'Cantrips Known',
          width: 116,
          align: TextAlign.center,
          value: (level) => _spellValue(level.spellcasting?.cantripsKnown),
        ),
      if (hasSpellcasting)
        _ProgressionColumn(
          key: 'spells',
          label: 'Spells Known',
          width: 112,
          align: TextAlign.center,
          value: (level) => _spellValue(level.spellcasting?.spellsKnown),
        ),
      for (final name in optionalColumnNames)
        _ProgressionColumn(
          key: 'optional:$name',
          label: name,
          width: 118,
          align: TextAlign.center,
          value: (level) => _optionalValue(level, name),
        ),
      if (hasSlots)
        for (var slot = 1; slot <= 9; slot++)
          _ProgressionColumn(
            key: 'slot:$slot',
            label: _slotLabel(slot),
            width: 58,
            align: TextAlign.center,
            value: (level) => _slotValue(level, slot),
          ),
    ];
  }

  Widget _buildGroupedHeader(List<_ProgressionColumn> columns) {
    final slotWidth = columns
        .where((column) => column.key.startsWith('slot:'))
        .fold<double>(0, (sum, column) => sum + column.width);
    final leftWidth = columns
        .where((column) => !column.key.startsWith('slot:'))
        .fold<double>(0, (sum, column) => sum + column.width);

    if (slotWidth == 0) return const SizedBox.shrink();

    return Row(
      children: [
        Container(
          width: leftWidth,
          height: 34,
          color: _progressHeader,
        ),
        Container(
          width: slotWidth,
          height: 34,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: _progressHeader,
            border: Border(
              left: BorderSide(color: _progressBorder),
            ),
          ),
          child: const Text(
            'Spell Slots per Spell Level',
            style: TextStyle(
              color: StitchCodexPalette.textPrimary,
              fontFamily: StitchTypography.data,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColumnHeader(List<_ProgressionColumn> columns) {
    return Row(
      children: columns.map((column) {
        return _TableCell(
          width: column.width,
          height: 54,
          color: _progressHeader,
          borderColor: _progressBorder,
          child: Text(
            column.label,
            textAlign: column.align,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: StitchCodexPalette.textPrimary,
              fontFamily: StitchTypography.data,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.08,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDataRow(
    DndClassLevel level,
    List<_ProgressionColumn> columns,
    int index,
  ) {
    final color = index.isEven ? _progressSurface : _progressSurfaceAlt;
    const rowHeight = 62.0;

    return Row(
      children: columns.map((column) {
        final isFeatures = column.key == 'features';

        return _TableCell(
          width: column.width,
          height: rowHeight,
          color: color,
          borderColor: _progressBorder.withValues(alpha: 0.42),
          alignment: isFeatures ? Alignment.centerLeft : Alignment.center,
          child: Text(
            column.value(level),
            textAlign: column.align,
            maxLines: isFeatures ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isFeatures
                  ? StitchCodexPalette.textSecondary
                  : StitchCodexPalette.textPrimary,
              fontFamily: isFeatures
                  ? StitchTypography.body
                  : StitchTypography.data,
              fontSize: isFeatures ? 13 : 14,
              fontWeight: isFeatures ? FontWeight.w400 : FontWeight.w700,
              height: 1.25,
            ),
          ),
        );
      }).toList(),
    );
  }

  String _spellValue(int? value) {
    if (value == null || value == 0) return '-';
    return value.toString();
  }

  String _slotValue(DndClassLevel level, int slot) {
    final slots = level.spellcasting?.spellSlots;
    if (slots == null || slots.length < slot) return '-';
    final value = slots[slot - 1];
    return value == 0 ? '-' : value.toString();
  }

  String _optionalValue(DndClassLevel level, String name) {
    final values = level.optionalProgression[name];
    if (values == null || values.isEmpty) return '-';
    final index = level.level - 1;
    if (index < 0 || index >= values.length) return '-';
    final value = values[index];
    return value == 0 ? '-' : value.toString();
  }

  String _slotLabel(int level) {
    switch (level) {
      case 1:
        return '1st';
      case 2:
        return '2nd';
      case 3:
        return '3rd';
      default:
        return '${level}th';
    }
  }

  String _ordinal(int level) {
    if (level == 1) return '1st';
    if (level == 2) return '2nd';
    if (level == 3) return '3rd';
    return '${level}th';
  }
}

class _TableCell extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final Color borderColor;
  final Alignment alignment;
  final Widget child;

  const _TableCell({
    required this.width,
    required this.height,
    required this.color,
    required this.borderColor,
    required this.child,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        border: Border(
          right: BorderSide(color: borderColor),
          bottom: BorderSide(color: borderColor),
        ),
      ),
      child: child,
    );
  }
}

class _ProgressionColumn {
  final String key;
  final String label;
  final double width;
  final TextAlign align;
  final String Function(DndClassLevel level) value;

  const _ProgressionColumn({
    required this.key,
    required this.label,
    required this.width,
    required this.value,
    this.align = TextAlign.left,
  });
}

class _NoLevelsMessage extends StatelessWidget {
  final String className;

  const _NoLevelsMessage({required this.className});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _progressSurface,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: _progressBorder.withValues(alpha: 0.55),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _progressBlue.withValues(alpha: 0.10),
                  border: Border.all(
                    color: _progressBlue.withValues(alpha: 0.30),
                  ),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: StitchCodexPalette.bronze,
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No progression table for $className',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: StitchCodexPalette.textPrimary,
                  fontFamily: StitchTypography.display,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'You can continue normally. This class does not have level progression data in the current dataset.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: StitchCodexPalette.textMuted,
                  fontFamily: StitchTypography.body,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
