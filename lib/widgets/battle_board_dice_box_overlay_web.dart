// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_util' as js_util;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/board_token.dart';

class BattleBoardDiceBoxOverlay extends StatefulWidget {
  final String boardViewportId;
  final BoardToken? token;
  final double gridSize;

  const BattleBoardDiceBoxOverlay({
    super.key,
    required this.boardViewportId,
    required this.token,
    required this.gridSize,
  });

  @override
  State<BattleBoardDiceBoxOverlay> createState() =>
      _BattleBoardDiceBoxOverlayState();
}

class _BattleBoardDiceBoxOverlayState extends State<BattleBoardDiceBoxOverlay> {
  static final Set<String> _registeredViewTypes = {};
  static int _nextOverlayIndex = 0;

  late final String _viewType =
      'battle-board-dice-box-${widget.boardViewportId}-${_nextOverlayIndex++}';

  String? _lastEventKey;

  @override
  void initState() {
    super.initState();

    _registerViewFactory();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_hasRollToken) {
        await _createDiceOverlay();
      }
      await _rollIfNeeded();
    });
  }

  @override
  void didUpdateWidget(covariant BattleBoardDiceBoxOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.token?.id != oldWidget.token?.id ||
        widget.token?.lastEventLabel != oldWidget.token?.lastEventLabel ||
        widget.token?.lastEventId != oldWidget.token?.lastEventId ||
        widget.token?.lastEventDiceColorHex !=
            oldWidget.token?.lastEventDiceColorHex ||
        widget.token?.updatedAt != oldWidget.token?.updatedAt) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (_hasRollToken) {
          await _createDiceOverlay();
        }
        await _rollIfNeeded();
      });
    }
  }

  @override
  void dispose() {
    _clearDice();
    super.dispose();
  }

  bool get _hasRollToken {
    final token = widget.token;
    return token != null && token.lastEventLabel.isNotEmpty;
  }

  void _registerViewFactory() {
    if (_registeredViewTypes.contains(_viewType)) return;

    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) {
        final element = html.DivElement()
          ..id = _viewType
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.position = 'relative'
          ..style.overflow = 'hidden'
          ..style.pointerEvents = 'none'
          ..style.userSelect = 'none';

        return element;
      },
    );

    _registeredViewTypes.add(_viewType);
  }

  Future<void> _createDiceOverlay({int retriesLeft = 3}) async {
    debugPrint(
      '[BattleBoardDiceBoxOverlay] createDiceOverlay($_viewType)',
    );

    final bridge = _bridge();

    if (bridge == null) {
      debugPrint('[BattleBoardDiceBoxOverlay] bridge missing');

      if (retriesLeft > 0) {
        await Future<void>.delayed(
          const Duration(milliseconds: 120),
        );

        return _createDiceOverlay(
          retriesLeft: retriesLeft - 1,
        );
      }

      return;
    }

    if (!await _waitForHtmlElement()) {
      debugPrint(
        '[BattleBoardDiceBoxOverlay] HtmlElementView not mounted yet: $_viewType',
      );

      if (retriesLeft > 0) {
        await Future<void>.delayed(
          const Duration(milliseconds: 120),
        );

        return _createDiceOverlay(
          retriesLeft: retriesLeft - 1,
        );
      }

      return;
    }

    try {
      js_util.callMethod(
        bridge,
        'createDiceOverlay',
        [_viewType],
      );
    } catch (error) {
      debugPrint(
        'Failed to create DiceBox overlay: $error',
      );
    }
  }

  Future<void> _rollIfNeeded() async {
    final token = widget.token;

    if (token == null || token.lastEventLabel.isEmpty) {
      debugPrint(
        '[BattleBoardDiceBoxOverlay] no event token or empty event label',
      );

      _lastEventKey = null;
      _clearDice();
      return;
    }

    final eventKey = '${token.id}:${token.lastEventId}:${token.lastEventLabel}:'
        '${token.updatedAt.millisecondsSinceEpoch}';

    debugPrint(
      '[BattleBoardDiceBoxOverlay] rollIfNeeded '
      'token=${token.id} '
      'label=${token.lastEventLabel} '
      'kind=${token.lastEventKind} '
      'eventKey=$eventKey '
      'lastEventKey=$_lastEventKey',
    );

    if (eventKey == _lastEventKey) {
      debugPrint(
        '[BattleBoardDiceBoxOverlay] event already processed, skipping',
      );

      return;
    }

    _lastEventKey = eventKey;

    await _createDiceOverlay();

    final notation = _notationForToken(token);
    final diceColorHex = _normalizedHexColor(token.lastEventDiceColorHex);
    final resultLabel = token.lastEventResultLabel.trim();
    final resultDetail = token.lastEventResultDetail.trim();

    await _rollDice(
      notation,
      diceColorHex: diceColorHex,
      resultLabel: resultLabel.isEmpty ? null : resultLabel,
      resultDetail: resultDetail.isEmpty ? null : resultDetail,
    );
  }

  Future<void> _rollDice(
    String notation, {
    String? diceColorHex,
    String? resultLabel,
    String? resultDetail,
  }) async {
    debugPrint(
      '[BattleBoardDiceBoxOverlay._rollDice] '
      'Starting roll with notation="$notation" color="$diceColorHex" '
      'viewType=$_viewType',
    );

    final bridge = await _waitForBridge();

    if (bridge == null) {
      debugPrint(
        '[BattleBoardDiceBoxOverlay._rollDice] bridge missing before roll',
      );

      return;
    }

    debugPrint(
      '[BattleBoardDiceBoxOverlay._rollDice] bridge found, calling rollDice',
    );

    try {
      await js_util.promiseToFuture(
        js_util.callMethod(
          bridge,
          'rollDice',
          [
            _viewType,
            notation,
            js_util.jsify({
              if (diceColorHex != null) 'themeColor': diceColorHex,
              if (resultLabel != null) 'resultLabel': resultLabel,
              if (resultDetail != null) 'resultDetail': resultDetail,
            }),
          ],
        ),
      );
      debugPrint(
        '[BattleBoardDiceBoxOverlay._rollDice] Roll completed successfully',
      );
    } catch (error) {
      debugPrint('DiceBox roll failed: $error');
    }
  }

  void _clearDice() {
    try {
      final bridge = _bridge();
      if (bridge == null) return;
      js_util.callMethod(
        bridge,
        'clearDice',
        [_viewType],
      );
    } catch (error) {
      debugPrint('DiceBox clear failed: $error');
    }
  }

  Future<dynamic> _waitForBridge({int attempts = 10}) async {
    for (var attempt = 0; attempt < attempts; attempt++) {
      final bridge = _bridge();

      if (bridge != null) return bridge;

      await Future<void>.delayed(
        const Duration(milliseconds: 120),
      );
    }

    return null;
  }

  Future<bool> _waitForHtmlElement({int attempts = 8}) async {
    for (var attempt = 0; attempt < attempts; attempt++) {
      final element = html.document.getElementById(_viewType);

      if (element != null) return true;

      await Future<void>.delayed(
        const Duration(milliseconds: 120),
      );
    }

    return false;
  }

  dynamic _bridge() {
    return js_util.getProperty(
      html.window,
      'stitchDiceBoxBridge',
    );
  }

  String _notationForToken(BoardToken token) {
    final explicitNotation = token.lastEventDiceNotation.trim();
    if (explicitNotation.isNotEmpty) {
      return _diceNotationFromLabel(explicitNotation) ?? explicitNotation;
    }

    final label = token.lastEventLabel.trim();
    final kind = token.lastEventKind.toLowerCase().trim();

    debugPrint(
      '[BattleBoardDiceBoxOverlay._notationForToken] '
      'label="$label" kind="$kind"',
    );

    if (kind == 'manual' || kind == 'custom' || kind == 'formula') {
      final notation = _diceNotationFromLabel(label) ?? '1d20';
      debugPrint(
        '[BattleBoardDiceBoxOverlay._notationForToken] '
        'Using parsed notation for manual/custom/formula label "$label": '
        '"$notation"',
      );
      return notation;
    }

    if (_looksLikeDiceNotation(label)) {
      final notation = _diceNotationFromLabel(label) ?? label;
      debugPrint(
        '[BattleBoardDiceBoxOverlay._notationForToken] '
        'Using parsed notation from label "$label": "$notation"',
      );
      return notation;
    }

    late final String notation;
    if (kind == 'heal') {
      notation = '1d8';
    } else if (kind == 'damage') {
      notation = '2d8';
    } else if (kind.contains('attack') ||
        kind.contains('save') ||
        kind.contains('spell')) {
      notation = '1d20';
    } else {
      notation = '1d20';
    }

    debugPrint(
      '[BattleBoardDiceBoxOverlay._notationForToken] '
      'Using default notation for kind "$kind": "$notation"',
    );
    return notation;
  }

  bool _looksLikeDiceNotation(String label) {
    return _diceNotationFromLabel(label) != null;
  }

  String? _diceNotationFromLabel(String label) {
    final normalized = label.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    final matches = RegExp(r'([+-]?)(\d*)d(\d+)').allMatches(normalized);
    final terms = <String>[];

    for (final match in matches) {
      final countText = match.group(2)!;
      final sidesText = match.group(3)!;
      final count = countText.isEmpty ? 1 : int.tryParse(countText);
      final sides = int.tryParse(sidesText);
      if (count == null || sides == null || count < 1 || sides < 2) {
        continue;
      }
      terms.add('${count}d$sides');
    }

    if (terms.isEmpty) return null;
    return terms.join('+');
  }

  String? _normalizedHexColor(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final normalized = trimmed.startsWith('#') ? trimmed : '#$trimmed';
    if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(normalized)) return null;
    return normalized.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.token == null || widget.token!.lastEventLabel.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox.expand(
      child: HtmlElementView(
        viewType: _viewType,
      ),
    );
  }
}
