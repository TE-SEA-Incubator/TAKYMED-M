
import 'package:flutter/material.dart';
import 'auth_screen.dart';

/// Connexion — même flux que le web (/login).
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthScreen(mode: AuthMode.login);
  }
}
