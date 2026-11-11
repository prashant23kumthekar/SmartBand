enum HeartZone { none, calm, steady, high, peak }

HeartZone zoneFor(int? bpm) {
  if (bpm == null || bpm <= 0) return HeartZone.none;
  if (bpm < 90) return HeartZone.calm;
  if (bpm < 120) return HeartZone.steady;
  if (bpm < 150) return HeartZone.high;
  return HeartZone.peak;
}

enum LinkState {
  unknown,
  bluetoothOff,
  unauthorized,
  idle,
  scanning,
  connecting,
  connected,
}

class HeartSample {
  HeartSample(this.time, this.bpm);
  final DateTime time;
  final int bpm;
}

class BandMetrics {
  BandMetrics({
    this.heartRate,
    this.steps,
    this.moving,
    this.battery,
    this.firmware,
    this.model,
    List<HeartSample>? samples,
  }) : samples = samples ?? [];

  int? heartRate;
  int? steps;
  bool? moving;
  int? battery;
  String? firmware;
  String? model;
  final List<HeartSample> samples;

  HeartZone get zone => zoneFor(heartRate);
}

class DiscoveredBand {
  DiscoveredBand({required this.id, required this.name, required this.rssi});
  final String id;
  String name;
  int rssi;
}

class BandIds {
  static const heartRateService = '180d';
  static const heartRate = '2a37';
  static const batteryService = '180f';
  static const battery = '2a19';
  static const deviceInfo = '180a';
  static const model = '2a24';
  static const firmware = '2a26';
  static const activity = 'fb5a0001-6c4b-4a5a-9f10-b1c2d3e4f500';
  static const steps = 'fb5a0002-6c4b-4a5a-9f10-b1c2d3e4f500';
  static const moving = 'fb5a0003-6c4b-4a5a-9f10-b1c2d3e4f500';
  static const advertisedName = 'SmartBand';
}
