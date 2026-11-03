import 'package:flutter/material.dart';
import 'package:smartband_companion/band_controller.dart';
import 'package:smartband_companion/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartBandApp());
}

class SmartBandApp extends StatefulWidget {
  const SmartBandApp({super.key, this.controller});

  final BandController? controller;

  @override
  State<SmartBandApp> createState() => _SmartBandAppState();
}

class _SmartBandAppState extends State<SmartBandApp> {
  late final BandController _band = widget.controller ?? BandController();

  @override
  void initState() {
    super.initState();
    _band.start();
  }

  @override
  void dispose() {
    _band.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartBand',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000),
        colorScheme: const ColorScheme.dark(
          surface: Color(0xFF000000),
          primary: Colors.white,
        ),
        fontFamily: 'Roboto',
      ),
      home: HomePage(band: _band),
    );
  }
}
