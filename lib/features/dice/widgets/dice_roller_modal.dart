import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme.dart';
import '../models/dice_roll_result.dart';
import '../services/dice_roller_service.dart';

class DiceRollerModal extends StatefulWidget {
  final void Function(DiceRollResult result)? onRoll;
  final String initialLabel;
  final int initialModifier;
  final int initialSides;
  final int initialDiceCount;
  final bool initialAdvantage;
  final bool initialDisadvantage;

  const DiceRollerModal({
    super.key,
    this.onRoll,
    this.initialLabel = 'Dice Roll',
    this.initialModifier = 0,
    this.initialSides = 20,
    this.initialDiceCount = 1,
    this.initialAdvantage = false,
    this.initialDisadvantage = false,
  });

  @override
  State<DiceRollerModal> createState() => _DiceRollerModalState();
}

class _DiceRollerModalState extends State<DiceRollerModal> {
  late final TextEditingController _formulaController;
  late final TextEditingController _labelController;

  late bool _advantage;
  late bool _disadvantage;

  final List<DiceRollResult> _history = [];
  DiceRollResult? _featuredResult;
  String? _formulaError;

  static const List<int> _diceOptions = [4, 6, 8, 10, 12, 20, 100];

  @override
  void initState() {
    super.initState();

    _formulaController = TextEditingController(
      text: _shouldStartBlank
          ? ''
          : _initialFormula(
              diceCount: widget.initialDiceCount,
              sides: widget.initialSides,
              modifier: widget.initialModifier,
            ),
    );
    _labelController = TextEditingController(text: widget.initialLabel);

    _advantage = widget.initialAdvantage;
    _disadvantage = widget.initialDisadvantage;
  }

  bool get _shouldStartBlank {
    return widget.initialLabel == 'Dice Roll' &&
        widget.initialModifier == 0 &&
        widget.initialSides == 20 &&
        widget.initialDiceCount == 1 &&
        !widget.initialAdvantage &&
        !widget.initialDisadvantage;
  }

  @override
  void dispose() {
    _formulaController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  String _initialFormula({
    required int diceCount,
    required int sides,
    required int modifier,
  }) {
    final safeDiceCount = diceCount < 1 ? 1 : diceCount;
    if (modifier == 0) return '${safeDiceCount}d$sides';
    return modifier > 0
        ? '${safeDiceCount}d$sides+$modifier'
        : '${safeDiceCount}d$sides$modifier';
  }

  void _appendDice(int sides) {
    final current = _formulaController.text.trim();
    final next = current.isEmpty ? '1d$sides' : '$current + 1d$sides';

    setState(() {
      _formulaController.text = next;
      _formulaController.selection = TextSelection.collapsed(
        offset: _formulaController.text.length,
      );
      _formulaError = null;
    });
  }

  bool get _canUseD20Mode {
    final normalized =
        _formulaController.text.replaceAll(' ', '').toLowerCase();
    return RegExp(r'^1?d20([+-]\d+)?$').hasMatch(normalized);
  }

  int _modifierFromSimpleD20Formula() {
    final normalized =
        _formulaController.text.replaceAll(' ', '').toLowerCase();
    final match = RegExp(r'^1?d20([+-]\d+)?$').firstMatch(normalized);
    if (match == null) return 0;
    return int.tryParse(match.group(1) ?? '0') ?? 0;
  }

  void _rollDice() {
    final label = _labelController.text.trim().isEmpty
        ? 'Dice Roll'
        : _labelController.text.trim();

    try {
      final result = (_canUseD20Mode && (_advantage || _disadvantage))
          ? DiceRollerService.roll(
              sides: 20,
              diceCount: 1,
              modifier: _modifierFromSimpleD20Formula(),
              advantage: _advantage,
              disadvantage: _disadvantage,
              label: label,
            )
          : DiceRollerService.rollFormula(
              formula: _formulaController.text,
              label: label,
            );

      setState(() {
        _formulaError = null;
        _featuredResult = result;
        _history.insert(0, result);
        if (_history.length > 12) {
          _history.removeLast();
        }
      });

      widget.onRoll?.call(result);
    } on FormatException catch (error) {
      setState(() {
        _formulaError = error.message;
      });
    }
  }

  Widget _buildDiceChoice(int sides) {
    return _DiceIconButton(
      sides: sides,
      onPressed: () => _appendDice(sides),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final canUseD20Mode = _canUseD20Mode;

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.58,
        maxChildSize: 0.96,
        builder: (context, scrollController) {
          return Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: tokens.panel,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
                border: Border(
                  top: BorderSide(
                    color: tokens.accentRead.withValues(alpha: 0.24),
                  ),
                ),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DiceHeader(featuredResult: _featuredResult),
                  const SizedBox(height: 14),
                  if (_featuredResult != null)
                    _FeaturedRollPanel(result: _featuredResult!),
                  if (_featuredResult != null) const SizedBox(height: 14),
                  TextField(
                    controller: _labelController,
                    decoration: const InputDecoration(
                      labelText: 'Label',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _formulaController,
                    decoration: InputDecoration(
                      labelText: 'Formula',
                      hintText: 'Example: d20+5, 2d6+3, 1d8+1d4+2',
                      prefixIcon: const Icon(Icons.functions),
                      errorText: _formulaError,
                    ),
                    onChanged: (_) {
                      setState(() {
                        _formulaError = null;
                        if (!_canUseD20Mode) {
                          _advantage = false;
                          _disadvantage = false;
                        }
                      });
                    },
                    onSubmitted: (_) => _rollDice(),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _diceOptions.map(_buildDiceChoice).toList(),
                  ),
                  const SizedBox(height: 12),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 160),
                    opacity: canUseD20Mode ? 1 : 0.45,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('Advantage'),
                          avatar: const Icon(Icons.arrow_upward, size: 15),
                          selected: _advantage,
                          onSelected: canUseD20Mode
                              ? (value) {
                                  setState(() {
                                    _advantage = value;
                                    if (value) _disadvantage = false;
                                  });
                                }
                              : null,
                        ),
                        FilterChip(
                          label: const Text('Disadvantage'),
                          avatar: const Icon(Icons.arrow_downward, size: 15),
                          selected: _disadvantage,
                          onSelected: canUseD20Mode
                              ? (value) {
                                  setState(() {
                                    _disadvantage = value;
                                    if (value) _advantage = false;
                                  });
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: _rollDice,
                      icon: const Icon(Icons.casino_outlined),
                      label: const Text('Roll Formula'),
                      style: FilledButton.styleFrom(
                        backgroundColor: tokens.accentAction,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text(
                        'RECENT ROLLS',
                        style: TextStyle(
                          color: tokens.accentReadSoft.withValues(alpha: 0.88),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      const Spacer(),
                      if (_history.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _history.clear();
                            });
                          },
                          child: const Text('Clear'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_history.isEmpty)
                    _EmptyDiceHistory()
                  else
                    ..._history.map((result) => _HistoryCard(result: result)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DiceHeader extends StatelessWidget {
  final DiceRollResult? featuredResult;

  const _DiceHeader({
    required this.featuredResult,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: tokens.accentAction.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(tokens.radiusSm),
            border: Border.all(
              color: tokens.accentAction.withValues(alpha: 0.26),
            ),
          ),
          child: const Icon(
            Icons.casino_outlined,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DICE ROLLER',
                style: TextStyle(
                  color: tokens.accentReadSoft.withValues(alpha: 0.90),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Roll formulas, attacks, checks and damage.',
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeaturedRollPanel extends StatelessWidget {
  final DiceRollResult result;

  const _FeaturedRollPanel({
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = result.isCriticalHit
        ? tokens.accentSuccess
        : result.isCriticalMiss
            ? tokens.accentAction
            : tokens.accentMagic;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.20),
            tokens.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.outcomeLabel.toUpperCase(),
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  result.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result.formula,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _TotalBadge(total: result.total, color: accent, large: true),
        ],
      ),
    );
  }
}

class _DiceIconButton extends StatelessWidget {
  final int sides;
  final VoidCallback onPressed;

  const _DiceIconButton({
    required this.sides,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Tooltip(
      message: 'Add d$sides',
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: tokens.accentRead.withValues(alpha: 0.22)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DieGlyph(sides: sides, size: 22),
            const SizedBox(width: 7),
            Text(
              'd$sides',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final DiceRollResult result;

  const _HistoryCard({
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = result.isCriticalHit
        ? tokens.accentSuccess
        : result.isCriticalMiss
            ? tokens.accentAction
            : tokens.accentRead;
    final time =
        '${result.timestamp.hour.toString().padLeft(2, '0')}:${result.timestamp.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          _DieGlyph(sides: result.sides, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.summaryText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${result.rollsText} • $time',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _TotalBadge(total: result.total, color: accent),
        ],
      ),
    );
  }
}

class _TotalBadge extends StatelessWidget {
  final int total;
  final Color color;
  final bool large;

  const _TotalBadge({
    required this.total,
    required this.color,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: large ? 70 : 48,
      height: large ? 70 : 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Text(
        '$total',
        style: TextStyle(
          color: Colors.white,
          fontSize: large ? 28 : 17,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _DieGlyph extends StatelessWidget {
  final int sides;
  final double size;

  const _DieGlyph({
    required this.sides,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final label = sides <= 0 ? 'F' : '$sides';

    return CustomPaint(
      size: Size.square(size),
      painter: _DieGlyphPainter(
        sides: sides,
        color: tokens.accentReadSoft,
        borderColor: tokens.accentRead,
      ),
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.34,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _DieGlyphPainter extends CustomPainter {
  final int sides;
  final Color color;
  final Color borderColor;

  const _DieGlyphPainter({
    required this.sides,
    required this.color,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path = Path();
    final safeSides = sides <= 0 ? 6 : sides;
    final points = safeSides == 4
        ? 3
        : safeSides == 6
            ? 4
            : safeSides == 8
                ? 6
                : safeSides == 10
                    ? 5
                    : safeSides == 12
                        ? 6
                        : 8;
    final radius = size.width * 0.43;
    final center = Offset(size.width / 2, size.height / 2);

    for (var index = 0; index < points; index++) {
      final angle = -1.5708 + (index * 6.28318 / points);
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    path.close();
    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _DieGlyphPainter oldDelegate) {
    return oldDelegate.sides != sides ||
        oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor;
  }
}

class _EmptyDiceHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentRead.withValues(alpha: 0.16)),
      ),
      child: Text(
        'No rolls yet. Try a formula like d20+5 or 2d6+3.',
        style: TextStyle(
          color: tokens.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
