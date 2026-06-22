import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_util' as js_util;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../models/board_dice_roll_outcome.dart';
import '../models/board_token.dart';

class BattleBoardDiceBoxOverlay extends StatefulWidget {
  final String boardViewportId;
  final BoardToken? token;
  final double gridSize;
  final Future<bool> Function(BoardToken token)? onRollClaimRequested;
  final FutureOr<void> Function(BoardToken token, BoardDiceRollOutcome outcome)?
      onRollResolved;

  const BattleBoardDiceBoxOverlay({
    super.key,
    required this.boardViewportId,
    required this.token,
    required this.gridSize,
    this.onRollClaimRequested,
    this.onRollResolved,
  });

  @override
  State<BattleBoardDiceBoxOverlay> createState() =>
      _BattleBoardDiceBoxOverlayState();
}

class _BattleBoardDiceBoxOverlayState extends State<BattleBoardDiceBoxOverlay> {
  static const Duration _claimTimeout = Duration(milliseconds: 1200);
  static final Set<String> _registeredViewTypes = {};
  static final Set<String> _completedEventKeys = {};
  static final Set<String> _activeEventKeys = {};

  late final String _viewType =
      'battle-board-dice-box-${widget.boardViewportId}';

  String? _lastEventKey;
  String? _rollingEventKey;
  Timer? _claimRetryTimer;
  StreamSubscription<html.Event>? _visibilitySubscription;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();

    _trace('initState view=$_viewType');
    _registerViewFactory();
    _visibilitySubscription = html.document.onVisibilityChange.listen((_) {
      if (html.document.visibilityState != 'visible') return;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        if (_hasRollToken) {
          await _createDiceOverlay();
        }
        await _rollIfNeeded();
      });
    });

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

    final rollIdentityChanged = widget.token?.id != oldWidget.token?.id ||
        widget.token?.lastEventId != oldWidget.token?.lastEventId ||
        widget.token?.lastEventDiceNotation !=
            oldWidget.token?.lastEventDiceNotation ||
        widget.token?.lastEventDiceColorHex !=
            oldWidget.token?.lastEventDiceColorHex;
    final resultVisualChanged = widget.token?.lastEventResultLabel !=
            oldWidget.token?.lastEventResultLabel ||
        widget.token?.lastEventResultDetail !=
            oldWidget.token?.lastEventResultDetail ||
        !_intListsMatch(
          widget.token?.lastEventRollValues ?? const <int>[],
          oldWidget.token?.lastEventRollValues ?? const <int>[],
        );

    if (rollIdentityChanged) {
      _trace(
        'didUpdate token=${widget.token?.id ?? '-'} '
        'event=${widget.token?.lastEventId ?? '-'} '
        'notation=${widget.token?.lastEventDiceNotation ?? '-'}',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (_hasRollToken) {
          await _createDiceOverlay();
        }
        await _rollIfNeeded();
      });
    }

    if (resultVisualChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _showResolvedResultPopup(widget.token);
      });
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _trace('dispose');
    _claimRetryTimer?.cancel();
    _visibilitySubscription?.cancel();
    _trace('dispose; dice stay visible until bridge auto-clear');
    super.dispose();
  }

  bool get _hasRollToken {
    final token = widget.token;
    return token != null &&
        token.lastEventLabel.isNotEmpty &&
        token.lastEventDiceNotation.trim().isNotEmpty;
  }

  void _registerViewFactory() {
    if (_registeredViewTypes.contains(_viewType)) return;

    ui_web.platformViewRegistry.registerViewFactory(
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
    _trace('registered HtmlElementView');
  }

  Future<bool> _createDiceOverlay({int retriesLeft = 3}) async {
    _trace('createDiceOverlay retries=$retriesLeft');

    final bridge = _bridge();

    if (bridge == null) {
      _trace('bridge missing');

      if (retriesLeft > 0) {
        await Future<void>.delayed(
          const Duration(milliseconds: 120),
        );

        return _createDiceOverlay(
          retriesLeft: retriesLeft - 1,
        );
      }

      return false;
    }

    if (!await _waitForHtmlElement()) {
      _trace('HtmlElementView not mounted yet');

      if (retriesLeft > 0) {
        await Future<void>.delayed(
          const Duration(milliseconds: 120),
        );

        return _createDiceOverlay(
          retriesLeft: retriesLeft - 1,
        );
      }

      return false;
    }

    try {
      final rawStatus = js_util.callMethod<Object?>(
        bridge,
        'createDiceOverlay',
        [_viewType],
      );
      final ok = rawStatus == null || _jsBool(rawStatus, 'ok') != false;
      final reason = _jsString(rawStatus, 'reason') ?? 'legacy/no-status';
      final width = _jsNum(rawStatus, 'width');
      final height = _jsNum(rawStatus, 'height');
      _trace(
        'createDiceOverlay result ok=$ok reason=$reason '
        'size=${width?.toStringAsFixed(0) ?? '-'}x'
        '${height?.toStringAsFixed(0) ?? '-'}',
      );
      _traceOverlayStatus();
      if (!ok && retriesLeft > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 180));
        return _createDiceOverlay(retriesLeft: retriesLeft - 1);
      }
      return ok;
    } catch (error) {
      _trace('createDiceOverlay exception: $error');
      return false;
    }
  }

  Future<void> _rollIfNeeded() async {
    final token = widget.token;

    if (token == null || token.lastEventLabel.isEmpty) {
      debugPrint(
        '[BattleBoardDiceBoxOverlay] no roll token or empty label',
      );
      _trace('no roll token/label; leaving dice until auto-clear');

      _lastEventKey = null;
      return;
    }

    if (token.lastEventDiceNotation.trim().isEmpty) {
      _trace('event has no dice notation; keeping current dice visible');
      return;
    }

    final eventIdentity = token.lastEventId.isEmpty
        ? token.updatedAt.microsecondsSinceEpoch.toString()
        : token.lastEventId;
    final eventKey = [
      token.sceneId,
      eventIdentity,
      token.lastEventDiceNotation,
      token.lastEventDiceColorHex,
    ].join(':');

    _trace(
      'rollIfNeeded '
      'token=${token.id} '
      'label=${token.lastEventLabel} '
      'kind=${token.lastEventKind} '
      'eventKey=$eventKey '
      'lastEventKey=$_lastEventKey',
    );

    if (eventKey == _lastEventKey) {
      _trace('event already processed, skipping');

      return;
    }

    if (token.lastEventRollValues.isNotEmpty) {
      _trace('event already has values=${token.lastEventRollValues}');
      _lastEventKey = eventKey;
      _rememberCompletedEvent(eventKey);
      await _showResolvedResultPopup(token);
      return;
    }

    if (_completedEventKeys.contains(eventKey)) {
      _trace('event completed in this client, skipping');
      _lastEventKey = eventKey;
      await _showResolvedResultPopup(token);
      return;
    }

    if (_rollingEventKey != null) {
      _trace('roll already in flight=$_rollingEventKey');
      return;
    }

    if (html.document.visibilityState == 'hidden') {
      _trace('page hidden; waiting before claim');
      return;
    }

    if (!_activeEventKeys.add(eventKey)) {
      _trace('event already rolling in another overlay, skipping');
      return;
    }
    _rollingEventKey = eventKey;
    try {
      if (!await _createDiceOverlay()) {
        if (_isDisposed || !mounted) return;
        _trace('overlay not ready; retry before claim');
        _scheduleClaimRetry(eventKey);
        return;
      }

      if (_isDisposed || !mounted) return;
      bool claimRoll;
      _trace('claim requested');
      claimRoll = await _claimRollOwnership(token);
      if (_isDisposed || !mounted) {
        _trace('claim resolved after dispose; aborting roll');
        return;
      }
      if (!claimRoll) {
        _trace('claim denied; retrying');
        _scheduleClaimRetry(eventKey);
        return;
      }
      _trace('claim accepted');

      _lastEventKey = eventKey;

      final notation = _notationForToken(token);
      final diceColorHex = _normalizedHexColor(token.lastEventDiceColorHex);

      _trace('roll start notation=$notation color=${diceColorHex ?? '-'}');
      final completed = await _rollDice(
        notation,
        diceColorHex: diceColorHex,
        eventKey: eventKey,
      );
      if (completed) {
        _trace('roll completed');
        _rememberCompletedEvent(eventKey);
      } else {
        _trace('roll returned no result; will retry');
        _lastEventKey = null;
        _scheduleClaimRetry(eventKey);
      }
    } catch (error) {
      _trace('roll flow exception: $error');
    } finally {
      _activeEventKeys.remove(eventKey);
      if (_rollingEventKey == eventKey) {
        _rollingEventKey = null;
      }
    }
  }

  Future<bool> _claimRollOwnership(BoardToken token) async {
    final claimCallback = widget.onRollClaimRequested;
    if (claimCallback == null) {
      _trace('claim skipped; no callback');
      return true;
    }

    try {
      return await claimCallback(token).timeout(
        _claimTimeout,
        onTimeout: () {
          _trace('claim timed out; rolling optimistically');
          return true;
        },
      );
    } catch (error) {
      _trace('claim failed; rolling optimistically: $error');
      return true;
    }
  }

  void _scheduleClaimRetry(String eventKey) {
    _trace('schedule retry event=$eventKey');
    _claimRetryTimer?.cancel();
    _claimRetryTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || _lastEventKey == eventKey) return;
      unawaited(_rollIfNeeded());
    });
  }

  void _rememberCompletedEvent(String eventKey) {
    _completedEventKeys.add(eventKey);
    while (_completedEventKeys.length > 200) {
      _completedEventKeys.remove(_completedEventKeys.first);
    }
  }

  Future<void> _showResolvedResultPopup(BoardToken? token) async {
    if (token == null) return;
    if (token.lastEventRollValues.isEmpty) return;
    final label = token.lastEventResultLabel.trim();
    if (label.isEmpty || label == 'ROLLING') return;

    await _createDiceOverlay();
    if (_isDisposed || !mounted) return;

    final detail = token.lastEventResultDetail.trim().isEmpty
        ? token.lastEventLabel.trim()
        : token.lastEventResultDetail.trim();
    try {
      final bridge = _bridge();
      if (bridge == null) return;
      js_util.callMethod(
        bridge,
        'showRollResult',
        [_viewType, label, detail],
      );
      _trace('resolved result popup label=$label');
    } catch (error) {
      _trace('resolved result popup failed: $error');
    }
  }

  Future<bool> _rollDice(
    String notation, {
    String? diceColorHex,
    required String eventKey,
  }) async {
    _trace('bridge roll call preparing');

    final bridge = await _waitForBridge();

    if (bridge == null) {
      _trace('bridge missing before roll');

      return false;
    }

    _trace('bridge found; calling rollDice');

    var waitingSeconds = 0;
    Timer? waitTraceTimer;
    try {
      waitTraceTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        waitingSeconds += 2;
        _trace('waiting JS dice outcome ${waitingSeconds}s');
        _traceOverlayStatus();
      });
      final rawOutcome = await js_util
          .promiseToFuture(
        js_util.callMethod(
          bridge,
          'rollDice',
          [
            _viewType,
            notation,
            js_util.jsify({
              if (diceColorHex != null) 'themeColor': diceColorHex,
              'eventKey': eventKey,
            }),
          ],
        ),
      )
          .timeout(
        const Duration(seconds: 24),
        onTimeout: () {
          _trace('Dart timed out waiting for JS dice outcome');
          return js_util.jsify({
            'error': 'dart-roll-timeout',
          });
        },
      );
      final outcome = _outcomeFromJsResult(rawOutcome);
      final token = widget.token;
      if (outcome != null && token != null) {
        _trace(
          'JS outcome total=${outcome.total} dice=${outcome.diceTotal} '
          'values=${outcome.values}',
        );
        final resolver = widget.onRollResolved;
        if (resolver != null) {
          await Future<void>.sync(() => resolver(token, outcome));
          _trace('outcome persisted callback completed');
        }
      } else {
        final error = _jsString(rawOutcome, 'error') ?? 'null/invalid outcome';
        _trace('JS outcome missing: $error');
        _traceOverlayStatus();
      }
      return outcome != null;
    } catch (error) {
      _trace('DiceBox roll exception: $error');
      _traceOverlayStatus();
      return false;
    } finally {
      waitTraceTimer?.cancel();
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

  void _trace(String message) {
    final line =
        '${DateTime.now().toIso8601String().substring(11, 19)} $message';
    debugPrint('[BattleBoardDiceDebug] $line');
    _writeDiceDebugLog(
      'trace',
      {
        'message': message,
        'viewType': _viewType,
        'lastEventKey': _lastEventKey,
        'rollingEventKey': _rollingEventKey,
        'token': _tokenLogData(widget.token),
      },
    );
  }

  void _writeDiceDebugLog(String stage, Map<String, Object?> data) {
    try {
      final bridge = _bridge();
      if (bridge == null) return;
      js_util.callMethod(
        bridge,
        'appendDiceDebugLog',
        [
          'dart',
          stage,
          js_util.jsify(data),
        ],
      );
    } catch (error) {
      debugPrint('Dice debug log write failed: $error');
    }
  }

  Map<String, Object?> _tokenLogData(BoardToken? token) {
    if (token == null) return {'hasToken': false};
    return {
      'hasToken': true,
      'id': token.id,
      'sceneId': token.sceneId,
      'refId': token.refId,
      'type': token.type,
      'name': token.name,
      'lastEventId': token.lastEventId,
      'lastEventLabel': token.lastEventLabel,
      'lastEventKind': token.lastEventKind,
      'lastEventDiceNotation': token.lastEventDiceNotation,
      'lastEventDiceColorHex': token.lastEventDiceColorHex,
      'lastEventResultLabel': token.lastEventResultLabel,
      'lastEventResultDetail': token.lastEventResultDetail,
      'lastEventRollTotal': token.lastEventRollTotal,
      'lastEventRollDiceTotal': token.lastEventRollDiceTotal,
      'lastEventRollValues': token.lastEventRollValues,
      'lastEventSourceRefId': token.lastEventSourceRefId,
      'lastEventPrimaryTargetRefId': token.lastEventPrimaryTargetRefId,
      'isVisible': token.isVisible,
      'isActive': token.isActive,
      'isTargeted': token.isTargeted,
      'updatedAt': token.updatedAt.toIso8601String(),
    };
  }

  void _traceOverlayStatus() {
    try {
      final bridge = _bridge();
      if (bridge == null) {
        _trace('status bridge=missing');
        return;
      }
      final status = js_util.callMethod<Object?>(
        bridge,
        'getOverlayStatus',
        [_viewType],
      );
      _trace(
        'status container=${_jsBool(status, 'hasContainer')} '
        'overlay=${_jsBool(status, 'hasOverlay')} '
        'init=${_jsString(status, 'initState') ?? '-'} '
        'roll=${_jsBool(status, 'hasRoll')} '
        'size=${_jsNum(status, 'width')?.toStringAsFixed(0) ?? '-'}x'
        '${_jsNum(status, 'height')?.toStringAsFixed(0) ?? '-'} '
        'source=${_jsString(status, 'lastRollSource') ?? '-'} '
        'err=${_jsString(status, 'lastError') ?? '-'}',
      );
    } catch (error) {
      _trace('status exception: $error');
    }
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

BoardDiceRollOutcome? _outcomeFromJsResult(Object? raw) {
  if (raw == null) return null;
  final total = _jsInt(raw, 'total');
  final diceTotal = _jsInt(raw, 'diceTotal') ?? total;
  if (total == null || diceTotal == null) return null;

  final values = <int>[];
  final valuesRaw = js_util.getProperty<Object?>(raw, 'values');
  if (valuesRaw != null) {
    final length = _jsInt(valuesRaw, 'length') ?? 0;
    for (var index = 0; index < length; index++) {
      final value = js_util.getProperty<Object?>(valuesRaw, index);
      if (value is num) {
        values.add(value.toInt());
      } else {
        final parsed = int.tryParse(value?.toString() ?? '');
        if (parsed != null) values.add(parsed);
      }
    }
  }

  final label =
      js_util.getProperty<Object?>(raw, 'label')?.toString().trim() ?? '';
  final detail =
      js_util.getProperty<Object?>(raw, 'detail')?.toString().trim() ?? '';

  return BoardDiceRollOutcome(
    total: total,
    diceTotal: diceTotal,
    values: values,
    label: label,
    detail: detail,
  );
}

int? _jsInt(Object raw, Object property) {
  final value = js_util.getProperty<Object?>(raw, property);
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _jsNum(Object? raw, Object property) {
  if (raw == null) return null;
  final value = js_util.getProperty<Object?>(raw, property);
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

bool? _jsBool(Object? raw, Object property) {
  if (raw == null) return null;
  final value = js_util.getProperty<Object?>(raw, property);
  if (value is bool) return value;
  return switch (value?.toString().toLowerCase()) {
    'true' => true,
    'false' => false,
    _ => null,
  };
}

String? _jsString(Object? raw, Object property) {
  if (raw == null) return null;
  final value = js_util.getProperty<Object?>(raw, property);
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

bool _intListsMatch(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}
