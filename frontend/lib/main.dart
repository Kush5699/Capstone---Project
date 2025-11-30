import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(CodeResidencyApp());
}

class CodeResidencyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CodeResidency',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: DashboardScreen(),
    );
  }
}
