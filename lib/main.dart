import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'app/theme_service.dart';
import 'core/services/language_service.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'firebase_options.dart';

import 'core/services/notification_service.dart';
import 'features/steps/data/step_repository.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint("Firebase initializeApp info: $e");
  }

  NotificationService.instance.navigatorKey = navigatorKey;

  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint("Firestore settings info: $e");
  }

  try {
    await ThemeService.initialize();
  } catch (e) {
    debugPrint("ThemeService init info: $e");
  }

  try {
    await LanguageService.initialize();
  } catch (e) {
    debugPrint("LanguageService init info: $e");
  }

  try {
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint("NotificationService init info: $e");
  }

  try {
    await StepRepository.instance.init();
  } catch (e) {
    debugPrint("StepRepository init info: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, themeMode, child) {
        return ValueListenableBuilder<String>(
          valueListenable: LanguageService.currentLanguageNotifier,
          builder: (context, language, child) {
            return MaterialApp(
              navigatorKey: navigatorKey,
              debugShowCheckedModeBanner: false,
              title: 'Calorix',
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeMode,
              builder: (context, child) {
                final mediaQuery = MediaQuery.of(context);
                final scale = mediaQuery.textScaler.scale(1.0).clamp(0.85, 1.2);
                return MediaQuery(
                  data: mediaQuery.copyWith(
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: child!,
                );
              },
              home: const SplashScreen(),
            );
          },
        );
      },
    );
  }
}
