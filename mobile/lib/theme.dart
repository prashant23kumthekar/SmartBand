import 'package:flutter/material.dart';
import 'package:smartband_companion/models.dart';

class Whoop {
  static const background = Color(0xFF000000);
  static const card = Color(0xFF171717);
  static const secondary = Color(0xFF9E9E9E);
  static const tertiary = Color(0xFF6B6B6B);
  static const calm = Color(0xFF29DB94);
  static const steady = Color(0xFF6BA3FF);
  static const high = Color(0xFFFACC47);
  static const peak = Color(0xFFFF6157);
  static const steps = Color(0xFFF5EBD1);
  static const live = Color(0xFF5CC7FF);

  static Color zoneColor(HeartZone zone) {
    switch (zone) {
      case HeartZone.none:
        return Colors.white54;
      case HeartZone.calm:
        return calm;
      case HeartZone.steady:
        return steady;
      case HeartZone.high:
        return high;
      case HeartZone.peak:
        return peak;
    }
  }
}

class WhoopCard extends StatelessWidget {
  const WhoopCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Whoop.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: child,
    );
  }
}
