import 'package:flutter/material.dart';
import 'core/di/injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const PulseApp());
}

class PulseApp extends StatelessWidget {
  const PulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pulse',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const Scaffold(
        body: Center(child: Text('Smt')),
      ),
    );
  }
}