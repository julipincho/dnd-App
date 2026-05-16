import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/battle_board_provider.dart';
import '../widgets/battle_board_view.dart';
import '../widgets/stitch_navigation.dart';

class BattleBoardScreen extends StatefulWidget {
  final String campaignId;
  final String sceneId;
  final bool readOnly;

  const BattleBoardScreen({
    super.key,
    required this.campaignId,
    required this.sceneId,
    this.readOnly = false,
  });

  @override
  State<BattleBoardScreen> createState() => _BattleBoardScreenState();
}

class _BattleBoardScreenState extends State<BattleBoardScreen> {
  String? _watchedSceneKey;

  @override
  void initState() {
    super.initState();
    _scheduleSceneWatch();
  }

  @override
  void didUpdateWidget(covariant BattleBoardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.campaignId != widget.campaignId ||
        oldWidget.sceneId != widget.sceneId) {
      _scheduleSceneWatch();
    }
  }

  void _scheduleSceneWatch() {
    final sceneKey = '${widget.campaignId}/${widget.sceneId}';
    if (_watchedSceneKey == sceneKey) return;
    _watchedSceneKey = sceneKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<BattleBoardProvider>().watchScene(
            campaignId: widget.campaignId,
            sceneId: widget.sceneId,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final boardProvider = context.watch<BattleBoardProvider>();
    final scene = boardProvider.activeScene;
    final tokens = boardProvider.tokens;

    return Scaffold(
      backgroundColor: const Color(0xFF070A0F),
      appBar: StitchAppBar(
        title: Text(scene?.name ?? 'Battle Board'),
        backgroundColor: const Color(0xFF070A0F),
        actions: [
          if (scene != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: Icon(
                  widget.readOnly
                      ? Icons.visibility_outlined
                      : Icons.gamepad_outlined,
                  size: 16,
                ),
                label: Text(widget.readOnly ? 'Display' : 'Controller'),
              ),
            ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (boardProvider.error != null) {
            return Center(
              child: Text(
                boardProvider.error!,
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          if (scene == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return Stack(
            children: [
              Positioned.fill(
                child: BattleBoardView(
                  scene: scene,
                  tokens: tokens,
                  readOnly: widget.readOnly,
                  onMoveToken: widget.readOnly
                      ? null
                      : (token, x, y) {
                          return context.read<BattleBoardProvider>().moveToken(
                                campaignId: scene.campaignId,
                                token: token,
                                x: x,
                                y: y,
                              );
                        },
                ),
              ),
              Positioned(
                left: 16,
                bottom: 16,
                child: _BoardHud(
                  sceneName: scene.name,
                  tokenCount: tokens.length,
                  readOnly: widget.readOnly,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BoardHud extends StatelessWidget {
  final String sceneName;
  final int tokenCount;
  final bool readOnly;

  const _BoardHud({
    required this.sceneName,
    required this.tokenCount,
    required this.readOnly,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.grid_on_outlined,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              '$sceneName - $tokenCount token${tokenCount == 1 ? '' : 's'}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (!readOnly) ...[
              const SizedBox(width: 12),
              const Text(
                'Drag tokens',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
