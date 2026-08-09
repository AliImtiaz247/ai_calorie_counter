import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../features/profile/data/profile_repository.dart';

import '../features/auth/presentation/start_screen.dart';
import '../features/home/presentation/home_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Firebase still checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = snapshot.data;

        // User not logged in
        if (user == null) {
          ProfileRepository().clearCache();

          return const StartScreen();
        }

        // Logged in
        return const HomeScreen();
      },
    );
  }
}