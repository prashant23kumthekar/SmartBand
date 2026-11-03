import 'package:flutter/material.dart';
import 'package:smartband_companion/band_controller.dart';
import 'package:smartband_companion/models.dart';
import 'package:smartband_companion/theme.dart';
import 'package:smartband_companion/widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.band});

  final BandController band;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: band,
      builder: (context, _) {
        final metrics = band.metrics;
        final zoneColor = Whoop.zoneColor(metrics.zone);
        return Scaffold(
          backgroundColor: Whoop.background,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                _Header(band: band),
                if (band.link != LinkState.connected) ...[
                  const SizedBox(height: 18),
                  _ConnectBanner(band: band),
                ],
                const SizedBox(height: 22),
                _Rings(band: band, zoneColor: zoneColor),
                const SizedBox(height: 22),
                _HeartCard(metrics: metrics, zoneColor: zoneColor),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _StepsCard(band: band)),
                    const SizedBox(width: 12),
                    Expanded(child: _MotionCard(moving: metrics.moving)),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Readings come from the band. Not a medical device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Whoop.tertiary, fontSize: 13),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.band});
  final BandController band;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              weekdayName(now),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
            ),
            Text(monthDay(now), style: const TextStyle(color: Whoop.secondary)),
          ],
        ),
        const Spacer(),
        TextButton(
          onPressed: () {
            if (band.link == LinkState.connected) {
              showModalBottomSheet<void>(
                context: context,
                backgroundColor: Whoop.background,
                builder: (context) => _DeviceSheet(band: band),
              );
            } else {
              _openConnect(context, band);
            }
          },
          child: _BatteryChip(
            level: band.metrics.battery,
            connected: band.link == LinkState.connected,
          ),
        ),
      ],
    );
  }
}

class _ConnectBanner extends StatelessWidget {
  const _ConnectBanner({required this.band});
  final BandController band;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Whoop.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openConnect(context, band),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.wifi_tethering),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _bannerTitle(band.link),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      band.statusMessage ??
                          'Search for the band to fill these rings.',
                      style: const TextStyle(
                        color: Whoop.secondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Whoop.tertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rings extends StatelessWidget {
  const _Rings({required this.band, required this.zoneColor});
  final BandController band;
  final Color zoneColor;

  @override
  Widget build(BuildContext context) {
    final metrics = band.metrics;
    return LayoutBuilder(
      builder: (context, constraints) {
        final center = (constraints.maxWidth * 0.40).clamp(120.0, 188.0);
        final side = center * 0.62;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _RingColumn(
              title: 'STEPS',
              size: side,
              stroke: 8,
              progress: _stepProgress(metrics.steps, band.stepScale),
              color: Whoop.steps,
              child: Text(
                compactSteps(metrics.steps),
                style: TextStyle(
                  fontSize: side * 0.22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _RingColumn(
              title: 'BPM',
              size: center,
              stroke: 12,
              progress: metrics.heartRate == null
                  ? 0
                  : (metrics.heartRate! / 180).clamp(0, 1),
              color: zoneColor,
              child: Text(
                metrics.heartRate?.toString() ?? '—',
                style: TextStyle(
                  fontSize: center * 0.30,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _RingColumn(
              title: metrics.moving == true ? 'MOVING' : 'STILL',
              size: side,
              stroke: 8,
              progress: metrics.moving == true ? 1 : 0.08,
              color: metrics.moving == true ? Whoop.live : Colors.white54,
              child: Icon(
                metrics.moving == true
                    ? Icons.directions_walk
                    : Icons.accessibility_new,
                size: side * 0.28,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RingColumn extends StatelessWidget {
  const _RingColumn({
    required this.title,
    required this.size,
    required this.stroke,
    required this.progress,
    required this.color,
    required this.child,
  });

  final String title;
  final double size;
  final double stroke;
  final double progress;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MetricRing(
          progress: progress,
          color: color,
          size: size,
          stroke: stroke,
          child: child,
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            color: Whoop.secondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.6,
          ),
        ),
      ],
    );
  }
}

class _HeartCard extends StatelessWidget {
  const _HeartCard({required this.metrics, required this.zoneColor});
  final BandMetrics metrics;
  final Color zoneColor;

  @override
  Widget build(BuildContext context) {
    final bpms = metrics.samples.map((sample) => sample.bpm);
    final low = bpms.isEmpty ? null : bpms.reduce((a, b) => a < b ? a : b);
    final high = bpms.isEmpty ? null : bpms.reduce((a, b) => a > b ? a : b);
    return WhoopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'HEART RATE',
                style: TextStyle(
                  color: Whoop.secondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.6,
                ),
              ),
              const Spacer(),
              Text(
                _zoneTitle(metrics.zone),
                style: TextStyle(
                  color: zoneColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                metrics.heartRate?.toString() ?? '—',
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'bpm',
                style: TextStyle(color: Whoop.secondary, fontSize: 16),
              ),
              const Spacer(),
              if (low != null && high != null)
                Text(
                  '$low–$high',
                  style: const TextStyle(color: Whoop.tertiary),
                ),
            ],
          ),
          const SizedBox(height: 8),
          HeartChart(samples: metrics.samples, color: zoneColor),
          const SizedBox(height: 8),
          Text(
            metrics.samples.isEmpty
                ? 'The band takes a short reading, then rests the sensor.'
                : 'Last reading ${relativeTime(metrics.samples.last.time)}',
            style: const TextStyle(color: Whoop.tertiary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _StepsCard extends StatelessWidget {
  const _StepsCard({required this.band});
  final BandController band;

  @override
  Widget build(BuildContext context) {
    return WhoopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'STEPS',
            style: TextStyle(
              color: Whoop.secondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            band.metrics.steps == null ? '—' : grouped(band.metrics.steps!),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
          ),
          Text(
            'scale ${grouped(band.stepScale)}',
            style: const TextStyle(color: Whoop.tertiary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _MotionCard extends StatelessWidget {
  const _MotionCard({required this.moving});
  final bool? moving;

  @override
  Widget build(BuildContext context) {
    final title = switch (moving) {
      true => 'Live',
      false => 'Still',
      null => '—',
    };
    return WhoopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ACTIVITY',
            style: TextStyle(
              color: Whoop.secondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
          ),
          Text(
            moving == null ? 'No motion yet' : 'From the accelerometer',
            style: const TextStyle(color: Whoop.tertiary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _BatteryChip extends StatelessWidget {
  const _BatteryChip({required this.level, required this.connected});
  final int? level;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final color = !connected
        ? Whoop.secondary
        : (level != null && level! < 20 ? Whoop.peak : Colors.white);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        level == null ? '—' : '$level%',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _DeviceSheet extends StatelessWidget {
  const _DeviceSheet({required this.band});
  final BandController band;

  @override
  Widget build(BuildContext context) {
    const scales = [5000, 8000, 10000, 15000];
    final parts = ['Connected'];
    if (band.metrics.model != null) parts.add(band.metrics.model!);
    if (band.metrics.firmware != null) parts.add('fw ${band.metrics.firmware}');
    return AnimatedBuilder(
      animation: band,
      builder: (context, _) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                band.deviceName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                parts.join(' · '),
                style: const TextStyle(color: Whoop.secondary),
              ),
              const SizedBox(height: 22),
              const Text(
                'STEP RING',
                style: TextStyle(
                  color: Whoop.secondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final scale in scales)
                    ChoiceChip(
                      label: Text(grouped(scale)),
                      selected: band.stepScale == scale,
                      onSelected: (_) => band.setStepScale(scale),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    band.disconnect();
                    Navigator.pop(context);
                  },
                  child: const Text('Disconnect'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectSheet extends StatelessWidget {
  const _ConnectSheet({required this.band});
  final BandController band;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: band,
      builder: (context, _) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Find your band',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Heart rate, steps, motion, and battery appear once SmartBand is connected.',
                  style: TextStyle(color: Whoop.secondary),
                ),
                const SizedBox(height: 18),
                if (band.discovered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        band.link == LinkState.scanning
                            ? 'Listening nearby'
                            : 'Ready to search',
                        style: const TextStyle(color: Whoop.secondary),
                      ),
                    ),
                  )
                else
                  for (final found in band.discovered)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(found.name),
                      subtitle: Text(_signal(found.rssi)),
                      trailing: const Icon(Icons.link),
                      onTap: () {
                        band.connect(found.id, name: found.name);
                        Navigator.pop(context);
                      },
                    ),
                if (band.statusMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    band.statusMessage!,
                    style: const TextStyle(color: Whoop.peak),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed:
                        band.link == LinkState.idle ||
                            band.link == LinkState.scanning
                        ? () {
                            if (band.link == LinkState.scanning) {
                              band.stopScan();
                            } else {
                              band.startScan();
                            }
                          }
                        : null,
                    child: Text(
                      band.link == LinkState.scanning ? 'Stop' : 'Search',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

void _openConnect(BuildContext context, BandController band) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Whoop.background,
    isScrollControlled: true,
    builder: (context) => _ConnectSheet(band: band),
  ).whenComplete(band.stopScan);
}

String _bannerTitle(LinkState link) {
  switch (link) {
    case LinkState.scanning:
      return 'Searching';
    case LinkState.connecting:
      return 'Connecting';
    case LinkState.bluetoothOff:
      return 'Bluetooth is off';
    case LinkState.unauthorized:
      return 'Bluetooth is blocked';
    default:
      return 'Connect your band';
  }
}

String _zoneTitle(HeartZone zone) {
  switch (zone) {
    case HeartZone.none:
      return 'WAITING';
    case HeartZone.calm:
      return 'CALM';
    case HeartZone.steady:
      return 'STEADY';
    case HeartZone.high:
      return 'HIGH';
    case HeartZone.peak:
      return 'PEAK';
  }
}

double _stepProgress(int? steps, int scale) {
  if (steps == null || scale <= 0) return 0;
  return (steps / scale).clamp(0, 1);
}

String _signal(int rssi) {
  if (rssi >= -60) return 'Strong signal';
  if (rssi >= -75) return 'Nearby';
  return 'Faint signal';
}
