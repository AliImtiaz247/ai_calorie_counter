import 'package:flutter/material.dart';
import '../features/splash/presentation/splash_screen.dart';
import 'theme.dart';

class CalorixApp extends StatelessWidget {
  const CalorixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Calorix',
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
