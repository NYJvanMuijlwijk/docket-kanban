import 'package:flutter/material.dart';

/// Screen that allows users to log in to their accounts.
class LoginScreen extends StatelessWidget {
  /// Creates a new instance of [LoginScreen].
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: const Center(
        child: Text('Login Screen Content Goes Here'),
      ),
    );
  }
}
