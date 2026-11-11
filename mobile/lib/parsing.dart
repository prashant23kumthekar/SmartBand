import 'dart:convert';
import 'dart:typed_data';

/// Bytes published by the band firmware.
int? parseHeartRate(Uint8List data) {
  if (data.length < 2) return null;
  final flags = data[0];
  final bpm = (flags & 0x01) == 0
      ? data[1]
      : (data.length >= 3 ? data[1] | (data[2] << 8) : null);
  if (bpm == null || bpm < 1 || bpm > 250) return null;
  return bpm;
}

int? parseSteps(Uint8List data) {
  if (data.length < 4) return null;
  return data[0] | (data[1] << 8) | (data[2] << 16) | (data[3] << 24);
}

bool? parseMoving(Uint8List data) {
  if (data.isEmpty) return null;
  return data[0] != 0;
}

int? parseBattery(Uint8List data) {
  if (data.isEmpty || data[0] > 100) return null;
  return data[0];
}

String? parseText(Uint8List data) {
  final end = data.indexOf(0);
  final bytes = end >= 0 ? data.sublist(0, end) : data;
  final text = utf8.decode(bytes, allowMalformed: true).trim();
  return text.isEmpty ? null : text;
}

/// Bluetooth base UUID form, lower case, so short and long ids compare equal.
String canonicalUuid(String uuid) {
  final hex = uuid.toLowerCase().replaceAll('-', '');
  if (hex.length == 4) {
    return '0000$hex-0000-1000-8000-00805f9b34fb';
  }
  if (hex.length == 32) {
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
  return uuid.toLowerCase();
}
