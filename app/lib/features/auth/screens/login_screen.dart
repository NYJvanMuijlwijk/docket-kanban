import 'package:app/features/auth/providers/auth_controller_provider.dart';
import 'package:app/shared/constants/app_spacing.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_validator/form_validator.dart';

/// Screen that allows users to log in to their accounts.
class LoginScreen extends ConsumerStatefulWidget {
  /// Creates a new instance of [LoginScreen].
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();

  Future<void> _register() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    await ref
        .read(authControllerProvider.notifier)
        .signUpWithEmailAndPassword(
          _emailController.text,
          _passwordController.text,
        );
  }

  Future<void> _login() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    await ref
        .read(authControllerProvider.notifier)
        .signInWithEmailAndPassword(
          _emailController.text,
          _passwordController.text,
        );
  }

  void _onAuthControllerState(
    AsyncValue<UserCredential?>? previous,
    AsyncValue<UserCredential?> next,
  ) {
    if (next.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(next.asError?.error.toString() ?? 'An error occurred'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = ref.watch(authControllerProvider);
    ref.listen(authControllerProvider, _onAuthControllerState);

    final passwordValidator = ValidationBuilder()
        .minLength(
          8,
          'Password must be at least 8 characters',
        )
        .maxLength(
          64,
          'Password must be less than 64 characters',
        )
        .regExp(
          RegExp(
            r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*(),.?":{}|<>]).+$',
          ),
          'Password must contain uppercase, lowercase,'
          ' number, and special character',
        )
        .build();

    final emailValidator = ValidationBuilder()
        .required('Email is required')
        .email('Please enter a valid email')
        .build();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: emailValidator,
                    ),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      validator: passwordValidator,
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: authController.isLoading
                              ? null
                              : _register,
                          child: authController.isLoading
                              ? const CircularProgressIndicator()
                              : const Text('Register'),
                        ),
                        const SizedBox(width: AppSpacing.medium),
                        ElevatedButton(
                          onPressed: authController.isLoading ? null : _login,
                          child: authController.isLoading
                              ? const CircularProgressIndicator()
                              : const Text('Login'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
