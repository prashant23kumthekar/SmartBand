import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartband_companion/parsing.dart';

void main() {
  test('heart rate uses the uint8 layout the firmware sends', () {
    expect(parseHeartRate(Uint8List.fromList([0x06, 72])), 72);
    expect(parseHeartRate(Uint8List.fromList([0x06, 0])), isNull);
    expect(parseHeartRate(Uint8List.fromList([0x01, 80, 0])), 80);
  });

  test('steps are a little-endian uint32', () {
    expect(parseSteps(Uint8List.fromList([0xE1, 0x10, 0x00, 0x00])), 4321);
  });

  test('moving and battery stay in range', () {
    expect(parseMoving(Uint8List.fromList([1])), isTrue);
    expect(parseMoving(Uint8List.fromList([0])), isFalse);
    expect(parseBattery(Uint8List.fromList([78])), 78);
    expect(parseBattery(Uint8List.fromList([255])), isNull);
  });

  test('short and long UUIDs compare equal', () {
    expect(
      canonicalUuid('2A37'),
      canonicalUuid('00002a37-0000-1000-8000-00805f9b34fb'),
    );
  });
}
