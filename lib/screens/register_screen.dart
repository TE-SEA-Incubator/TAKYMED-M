
import 'package:flutter/material.dart';
import 'auth_screen.dart';

/// Inscription — même flux que le web (/register) : SMS PIN puis connexion.
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthScreen(mode: AuthMode.register);
  }
}
