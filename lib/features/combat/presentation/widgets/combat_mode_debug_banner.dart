import 'package:flutter/material.dart';

class CombatModeDebugBanner extends StatelessWidget {
  final String location;
  final String detail;

  const CombatModeDebugBanner({
    super.key,
    required this.location,
    this.detail = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.yellow,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Text(
        'DEBUG COMBAT MODE ACTIVO - $location${detail.isEmpty ? '' : ' - $detail'} - ${DateTime.now().millisecondsSinceEpoch}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}
