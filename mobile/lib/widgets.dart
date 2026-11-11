import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:smartband_companion/models.dart';

class MetricRing extends StatelessWidget {
  const MetricRing({
    super.key,
    required this.progress,
    required this.color,
    required this.size,
    this.stroke = 10,
    required this.child,
  });

  final double progress;
  final Color color;
  final double size;
  final double stroke;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(progress: progress, color: color, stroke: stroke),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.stroke,
  });

  final double progress;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white.withValues(alpha: 0.08),
    );
    final sweep = 2 * math.pi * progress.clamp(0, 1);
    if (sweep <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.stroke != stroke;
  }
}

class HeartChart extends StatelessWidget {
  const HeartChart({super.key, required this.samples, required this.color});

  final List<HeartSample> samples;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ChartPainter(samples: samples, color: color),
      child: const SizedBox(height: 112, width: double.infinity),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({required this.samples, required this.color});

  final List<HeartSample> samples;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = Colors.white.withValues(alpha: 0.06);
    for (var i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (samples.isEmpty) return;

    final values = samples.map((sample) => sample.bpm.toDouble()).toList();
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final low = maxV - minV >= 4 ? minV - (maxV - minV) * 0.2 : minV - 6;
    final high = maxV - minV >= 4 ? maxV + (maxV - minV) * 0.2 : maxV + 6;

    Offset point(int index) {
      final x = samples.length == 1
          ? size.width / 2
          : size.width * index / (samples.length - 1);
      final t = ((values[index] - low) / (high - low)).clamp(0.0, 1.0);
      return Offset(x, size.height - size.height * t);
    }

    final line = Path();
    if (samples.length == 1) {
      final y = point(0).dy;
      line.moveTo(0, y);
      line.lineTo(size.width, y);
    } else {
      line.moveTo(point(0).dx, point(0).dy);
      for (var i = 1; i < samples.length; i++) {
        line.lineTo(point(i).dx, point(i).dy);
      }
    }

    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.32),
            color.withValues(alpha: 0.02),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_ChartPainter oldDelegate) {
    return oldDelegate.samples != samples || oldDelegate.color != color;
  }
}

String grouped(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) buffer.write(',');
    buffer.write(text[i]);
  }
  return buffer.toString();
}

String compactSteps(int? steps) {
  if (steps == null) return '—';
  if (steps < 1000) return '$steps';
  final scaled = steps / 1000;
  final text = scaled.toStringAsFixed(1);
  return text.endsWith('.0')
      ? '${text.substring(0, text.length - 2)}k'
      : '${text}k';
}

String weekdayName(DateTime date) {
  const names = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return names[date.weekday - 1];
}

String monthDay(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

String relativeTime(DateTime time) {
  final elapsed = DateTime.now().difference(time);
  if (elapsed.inSeconds < 45) return 'just now';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}m ago';
  if (elapsed.inHours < 24) return '${elapsed.inHours}h ago';
  return '${elapsed.inDays}d ago';
}
