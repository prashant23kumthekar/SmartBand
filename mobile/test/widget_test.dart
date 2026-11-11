import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartband_companion/band_controller.dart';
import 'package:smartband_companion/main.dart';

void main() {
  testWidgets('connected preview shows heart rate and steps', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(SmartBandApp(controller: BandController.preview()));
    expect(find.text('72'), findsWidgets);
    expect(find.text('4.3k'), findsOneWidget);
    expect(find.text('4,281'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('78%'), findsOneWidget);
  });

  testWidgets('empty band asks to connect', (tester) async {
    await tester.pumpWidget(SmartBandApp(controller: BandController.offline()));
    await tester.pump();
    expect(find.text('Connect your band'), findsOneWidget);
    expect(find.text('—'), findsWidgets);
  });
}
