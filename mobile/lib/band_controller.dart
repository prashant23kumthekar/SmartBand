import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartband_companion/models.dart';
import 'package:smartband_companion/parsing.dart';
import 'package:universal_ble/universal_ble.dart';

class BandController extends ChangeNotifier {
  BandController._({required this._preview});

  factory BandController() => BandController._(preview: false);

  /// UI-only controller. It never opens the Bluetooth stack.
  factory BandController.offline() => BandController._(preview: true);

  factory BandController.preview() {
    final start = DateTime.now().subtract(const Duration(minutes: 48));
    final samples = List.generate(
      48,
      (index) => HeartSample(
        start.add(Duration(minutes: index)),
        64 + (index % 9) + (index > 30 ? 8 : 0),
      ),
    );
    return BandController._(preview: true)
      ..link = LinkState.connected
      ..deviceName = BandIds.advertisedName
      ..metrics = BandMetrics(
        heartRate: 72,
        steps: 4281,
        moving: true,
        battery: 78,
        firmware: '0.4.0',
        model: 'SmartBand',
        samples: samples,
      );
  }

  final bool _preview;
  LinkState link = LinkState.unknown;
  BandMetrics metrics = BandMetrics();
  List<DiscoveredBand> discovered = [];
  String? statusMessage;
  String deviceName = BandIds.advertisedName;
  int stepScale = 10000;

  bool _shouldReconnect = true;
  String? _deviceId;
  bool _discovering = false;

  StreamSubscription<BleDevice>? _scanSub;
  StreamSubscription<AvailabilityState>? _availabilitySub;
  StreamSubscription<bool>? _connectionSub;
  final List<StreamSubscription<Uint8List>> _valueSubs = [];

  static const _deviceKey = 'smartband.deviceId';
  static const _scaleKey = 'smartband.stepScale';

  Future<void> start() async {
    if (_preview) return;
    final prefs = await SharedPreferences.getInstance();
    stepScale = prefs.getInt(_scaleKey) ?? 10000;
    try {
      await UniversalBle.requestPermissions();
    } catch (_) {}
    _availabilitySub ??= UniversalBle.availabilityStream.listen(
      _onAvailability,
    );
    try {
      _onAvailability(await UniversalBle.getBluetoothAvailabilityState());
    } catch (error) {
      link = LinkState.bluetoothOff;
      statusMessage = 'Bluetooth is not available on this computer.';
      notifyListeners();
      debugPrint('Bluetooth availability: $error');
    }
  }

  Future<void> setStepScale(int scale) async {
    stepScale = scale;
    notifyListeners();
    if (_preview) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_scaleKey, scale);
  }

  Future<void> startScan() async {
    if (_preview) return;
    discovered = [];
    statusMessage = null;
    link = LinkState.scanning;
    notifyListeners();
    _scanSub ??= UniversalBle.scanStream.listen(_onScan);
    try {
      await UniversalBle.startScan(
        scanFilter: ScanFilter(withServices: [BandIds.heartRateService]),
      );
    } catch (error) {
      link = LinkState.idle;
      statusMessage = 'Search failed. Check that Bluetooth is on.';
      notifyListeners();
      debugPrint('Scan: $error');
    }
  }

  Future<void> stopScan() async {
    if (_preview) return;
    try {
      await UniversalBle.stopScan();
    } catch (_) {}
    if (link == LinkState.scanning) {
      link = LinkState.idle;
      notifyListeners();
    }
  }

  Future<void> connect(String id, {String? name}) async {
    if (_preview) return;
    await stopScan();
    _shouldReconnect = true;
    _deviceId = id;
    if (name != null) deviceName = name;
    link = LinkState.connecting;
    statusMessage = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceKey, id);
    _listen(id);
    try {
      await UniversalBle.connect(id, timeout: const Duration(seconds: 20));
    } catch (error) {
      link = LinkState.idle;
      statusMessage =
          'Could not connect. Move the band closer and search again.';
      notifyListeners();
      debugPrint('Connect: $error');
    }
  }

  Future<void> disconnect() async {
    _shouldReconnect = false;
    final id = _deviceId;
    _deviceId = null;
    if (!_preview) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_deviceKey);
      if (id != null) {
        try {
          await UniversalBle.disconnect(id);
        } catch (_) {}
      }
    }
    await _dropValues();
    link = LinkState.idle;
    notifyListeners();
  }

  void _onAvailability(AvailabilityState state) {
    switch (state) {
      case AvailabilityState.poweredOn:
        statusMessage = null;
        if (link != LinkState.connected && link != LinkState.connecting) {
          link = LinkState.idle;
        }
        notifyListeners();
        unawaited(_reconnectSaved());
      case AvailabilityState.poweredOff:
        link = LinkState.bluetoothOff;
        statusMessage = 'Turn Bluetooth on to reach the band.';
        notifyListeners();
      case AvailabilityState.unauthorized:
        link = LinkState.unauthorized;
        statusMessage = 'Allow Bluetooth for SmartBand.';
        notifyListeners();
      case AvailabilityState.unsupported:
        link = LinkState.bluetoothOff;
        statusMessage = 'This computer has no Bluetooth radio the app can use.';
        notifyListeners();
      case AvailabilityState.unknown:
      case AvailabilityState.resetting:
        break;
    }
  }

  Future<void> _reconnectSaved() async {
    if (!_shouldReconnect || _deviceId != null || link == LinkState.connected) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_deviceKey);
    if (saved == null) return;
    await connect(saved);
  }

  void _listen(String id) {
    _connectionSub?.cancel();
    _connectionSub = UniversalBle.connectionStream(id).listen((connected) {
      if (connected) {
        link = LinkState.connected;
        statusMessage = null;
        notifyListeners();
        unawaited(_discover(id));
      } else if (_shouldReconnect && _deviceId == id) {
        link = LinkState.connecting;
        notifyListeners();
        unawaited(_reconnect(id));
      } else {
        link = LinkState.idle;
        notifyListeners();
      }
    });
  }

  Future<void> _reconnect(String id) async {
    try {
      await UniversalBle.connect(id, timeout: const Duration(seconds: 20));
    } catch (error) {
      link = LinkState.idle;
      statusMessage = 'The band disconnected.';
      notifyListeners();
      debugPrint('Reconnect: $error');
    }
  }

  void _onScan(BleDevice device) {
    final name = device.name ?? device.rawName;
    if (name == null ||
        name.toLowerCase() != BandIds.advertisedName.toLowerCase()) {
      return;
    }
    final rssi = device.rssi ?? -90;
    final shown = (rssi > 0 || rssi < -120) ? -90 : rssi;
    final next = [...discovered];
    final index = next.indexWhere((item) => item.id == device.deviceId);
    if (index >= 0) {
      next[index].rssi = shown;
      next[index].name = name;
    } else {
      next.add(DiscoveredBand(id: device.deviceId, name: name, rssi: shown));
    }
    next.sort((a, b) => b.rssi.compareTo(a.rssi));
    discovered = next;
    notifyListeners();
  }

  Future<void> _discover(String id) async {
    if (_discovering) return;
    _discovering = true;
    try {
      final services = await UniversalBle.discoverServices(id);
      await _dropValues();
      for (final service in services) {
        for (final characteristic in service.characteristics) {
          final uuid = canonicalUuid(characteristic.uuid);
          if (characteristic.properties.contains(CharacteristicProperty.read)) {
            try {
              final value = await UniversalBle.read(
                id,
                service.uuid,
                characteristic.uuid,
              );
              _apply(uuid, value);
            } catch (error) {
              debugPrint('Read $uuid: $error');
            }
          }
          if (characteristic.properties.contains(
                CharacteristicProperty.notify,
              ) ||
              characteristic.properties.contains(
                CharacteristicProperty.indicate,
              )) {
            try {
              if (characteristic.properties.contains(
                CharacteristicProperty.indicate,
              )) {
                await UniversalBle.subscribeIndications(
                  id,
                  service.uuid,
                  characteristic.uuid,
                );
              } else {
                await UniversalBle.subscribeNotifications(
                  id,
                  service.uuid,
                  characteristic.uuid,
                );
              }
              _valueSubs.add(
                UniversalBle.characteristicValueStream(
                  id,
                  characteristic.uuid,
                ).listen((value) => _apply(uuid, value)),
              );
            } catch (error) {
              debugPrint('Subscribe $uuid: $error');
            }
          }
        }
      }
    } catch (error) {
      statusMessage = 'Connected, but the band services were not readable.';
      notifyListeners();
      debugPrint('Discover: $error');
    } finally {
      _discovering = false;
    }
  }

  Future<void> _dropValues() async {
    for (final sub in _valueSubs) {
      await sub.cancel();
    }
    _valueSubs.clear();
  }

  void _apply(String uuid, Uint8List data) {
    final id = canonicalUuid(uuid);
    if (id == canonicalUuid(BandIds.heartRate)) {
      final bpm = parseHeartRate(data);
      if (bpm == null) return;
      metrics.heartRate = bpm;
      metrics.samples.add(HeartSample(DateTime.now(), bpm));
      if (metrics.samples.length > 120) {
        metrics.samples.removeRange(0, metrics.samples.length - 120);
      }
    } else if (id == canonicalUuid(BandIds.battery)) {
      final level = parseBattery(data);
      if (level == null) return;
      metrics.battery = level;
    } else if (id == canonicalUuid(BandIds.steps)) {
      final steps = parseSteps(data);
      if (steps == null) return;
      metrics.steps = steps;
    } else if (id == canonicalUuid(BandIds.moving)) {
      final moving = parseMoving(data);
      if (moving == null) return;
      metrics.moving = moving;
    } else if (id == canonicalUuid(BandIds.firmware)) {
      final text = parseText(data);
      if (text == null) return;
      metrics.firmware = text;
    } else if (id == canonicalUuid(BandIds.model)) {
      final text = parseText(data);
      if (text == null) return;
      metrics.model = text;
    } else {
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _availabilitySub?.cancel();
    _connectionSub?.cancel();
    for (final sub in _valueSubs) {
      sub.cancel();
    }
    super.dispose();
  }
}
