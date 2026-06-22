import 'package:flutter/material.dart';

import '../models/battle_scene.dart';
import '../models/board_token.dart';
import '../widgets/battle_board_view.dart';
import '../widgets/stitch_navigation.dart';

class BattleBoardDemoScreen extends StatefulWidget {
  final bool readOnly;

  const BattleBoardDemoScreen({
    super.key,
    this.readOnly = false,
  });

  @override
  State<BattleBoardDemoScreen> createState() => _BattleBoardDemoScreenState();
}

class _BattleBoardDemoScreenState extends State<BattleBoardDemoScreen> {
  late final BattleScene _scene;
  late List<BoardToken> _tokens;
  String? _selectedTokenId;

  @override
  void initState() {
    super.initState();
    _scene = BattleScene.create(
      id: 'demo-board-scene',
      campaignId: 'demo-campaign',
      name: 'Demo Battle Board',
      mapImageUrl: 'assets/images/combat/dungeon_battlefield.png',
      gridSize: 64,
      gridColumns: 24,
      gridRows: 16,
      combatActive: true,
    );
    _tokens = [
      BoardToken.create(
        id: 'demo-arnnazal',
        sceneId: _scene.id,
        refId: 'demo-arnnazal',
        type: 'character',
        name: 'Arnnazal',
        imageUrl: 'assets/images/races/half-orc.png',
        x: 3,
        y: 5,
        currentHp: 174,
        maxHp: 174,
        conditions: const ['Blessed'],
      ),
      BoardToken.create(
        id: 'demo-lyra',
        sceneId: _scene.id,
        refId: 'demo-lyra',
        type: 'character',
        name: 'Lyra',
        imageUrl: 'assets/images/classes/wizard.png',
        x: 4,
        y: 8,
        currentHp: 32,
        maxHp: 38,
        conditions: const ['Concentrating'],
      ),
      BoardToken.create(
        id: 'demo-captain',
        sceneId: _scene.id,
        refId: 'demo-captain',
        type: 'monster',
        name: 'Captain',
        imageUrl: 'assets/images/races/hobgoblin.png',
        x: 16,
        y: 5,
        currentHp: 48,
        maxHp: 65,
      ),
      BoardToken.create(
        id: 'demo-goblin',
        sceneId: _scene.id,
        refId: 'demo-goblin',
        type: 'monster',
        name: 'Goblin',
        imageUrl: 'assets/images/races/goblin.png',
        x: 18,
        y: 9,
        currentHp: 11,
        maxHp: 17,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070A0F),
      appBar: StitchAppBar(
        title: const Text('Battle Board Demo'),
        backgroundColor: const Color(0xFF070A0F),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              avatar: Icon(
                widget.readOnly
                    ? Icons.visibility_outlined
                    : Icons.gamepad_outlined,
                size: 16,
              ),
              label: Text(widget.readOnly ? 'Virtual monitor' : 'Controller'),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: BattleBoardView(
              scene: _scene,
              tokens: _tokens,
              readOnly: widget.readOnly,
              selectedTokenId: widget.readOnly ? null : _selectedTokenId,
              onTokenTap: widget.readOnly
                  ? null
                  : (token) {
                      setState(() {
                        _selectedTokenId = token.id;
                      });
                    },
              onBoardCellTap: widget.readOnly ? null : _moveSelectedToken,
              onMoveToken: widget.readOnly ? null : _moveToken,
            ),
          ),
          Positioned(
            left: 16,
            bottom: 16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.68),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Text(
                  widget.readOnly
                      ? 'Display local: /board-demo?mode=display'
                      : 'Demo local: selecciona una ficha y toca una casilla',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _moveToken(BoardToken token, int x, int y) async {
    setState(() {
      _tokens = [
        for (final item in _tokens)
          if (item.id == token.id) item.copyWith(x: x, y: y) else item,
      ];
    });
  }

  Future<void> _moveSelectedToken(int x, int y) async {
    final selectedId = _selectedTokenId;
    if (selectedId == null) return;
    final matching = _tokens.where((token) => token.id == selectedId);
    if (matching.isEmpty) return;
    await _moveToken(matching.first, x, y);
  }
}
