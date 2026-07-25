import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../bloc/auth_bloc.dart';

/// Экран регистрации нового пользователя
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  bool _usePhone = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthOtpSent) {
          context.go('/verify', extra: {
            'identifier': state.identifier,
            'method': state.method,
          });
        }
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: context.colors.error),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Регистрация')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [context.colors.primary, context.colors.secondary],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.primary.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.bolt, color: Colors.white, size: 36),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Создайте аккаунт',
                  style: context.typography.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Заполните данные для регистрации в ЧАРО',
                  style: context.typography.bodyMedium?.copyWith(
                    color: context.colors.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 32),

                // Имя пользователя
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    hintText: 'username',
                    prefixIcon: Icon(Icons.alternate_email),
                    helperText: 'Только латиница, цифры и _',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Введите имя пользователя';
                    if (v.length < 3) return 'Минимум 3 символа';
                    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v)) {
                      return 'Только латиница, цифры и _';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Отображаемое имя
                TextFormField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    hintText: 'Ваше имя',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Введите ваше имя' : null,
                ),
                const SizedBox(height: 24),

                // Переключатель телефон/email
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Телефон')),
                    ButtonSegment(value: false, label: Text('Email')),
                  ],
                  selected: {_usePhone},
                  onSelectionChanged: (v) => setState(() => _usePhone = v.first),
                ),
                const SizedBox(height: 16),

                // Телефон или email
                if (_usePhone)
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: '+7 (999) 123-45-67',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Введите номер телефона' : null,
                  )
                else
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      hintText: 'you@example.com',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? 'Введите корректный email' : null,
                  ),
                const SizedBox(height: 32),

                // Кнопка регистрации
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    final isLoading = state is AuthLoading;
                    return FilledButton(
                      onPressed: isLoading ? null : _onRegister,
                      child: isLoading
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Зарегистрироваться'),
                    );
                  },
                ),
                const SizedBox(height: 16),

                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Уже есть аккаунт? Войти'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onRegister() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(AuthRegisterRequested(
          username: _usernameController.text.trim(),
          displayName: _displayNameController.text.trim(),
          phone: _usePhone ? _phoneController.text.trim() : null,
          email: !_usePhone ? _emailController.text.trim() : null,
        ));
  }
}
