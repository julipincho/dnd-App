import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_app/models/battle_scene.dart';
import 'package:stitch_app/models/board_token.dart';

void main() {
  group('Battle board models', () {
    test('BattleScene preserves the tactical scene payload', () {
      final timestamp = DateTime(2026, 5, 16, 10, 30);
      final scene = BattleScene.create(
        id: 'scene-1',
        campaignId: 'campaign-1',
        name: 'Bridge Ambush',
        mapImageUrl: 'maps/bridge.png',
        gridSize: 72,
        gridColumns: 30,
        gridRows: 20,
        combatActive: true,
        now: timestamp,
      );

      final restored = BattleScene.fromJson(scene.toJson());

      expect(restored.id, 'scene-1');
      expect(restored.campaignId, 'campaign-1');
      expect(restored.name, 'Bridge Ambush');
      expect(restored.mapImageUrl, 'maps/bridge.png');
      expect(restored.gridSize, 72);
      expect(restored.gridColumns, 30);
      expect(restored.gridRows, 20);
      expect(restored.combatActive, isTrue);
      expect(restored.createdAt, timestamp);
      expect(restored.updatedAt, timestamp);
    });

    test('BoardToken preserves sync fields and movement updates', () {
      final token = BoardToken.create(
        id: 'token-1',
        sceneId: 'scene-1',
        refId: 'character-1',
        type: 'character',
        name: 'Arnnazal',
        imageUrl: 'assets/images/races/half-orc.png',
        x: 3,
        y: 4,
        currentHp: 31,
        maxHp: 40,
        conditions: const ['Blessed'],
        controlledByUserId: 'user-1',
        now: DateTime(2026, 5, 16, 11),
      );

      final moved = token.copyWith(x: 5, y: 7);
      final restored = BoardToken.fromJson(moved.toJson());

      expect(restored.id, 'token-1');
      expect(restored.sceneId, 'scene-1');
      expect(restored.refId, 'character-1');
      expect(restored.type, 'character');
      expect(restored.name, 'Arnnazal');
      expect(restored.imageUrl, 'assets/images/races/half-orc.png');
      expect(restored.x, 5);
      expect(restored.y, 7);
      expect(restored.currentHp, 31);
      expect(restored.maxHp, 40);
      expect(restored.conditions, const ['Blessed']);
      expect(restored.controlledByUserId, 'user-1');
      expect(restored.isVisible, isTrue);
    });
  });
}
