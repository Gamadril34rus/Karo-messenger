// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/haptic/haptic_service.dart';
import '../bloc/auth_bloc.dart';

/// Экран восстановления удалённого аккаунта (30-дневный grace period)
class AccountRecoveryScreen extends StatefulWidget {
  final String accountId;
  final String recoveryCode;

  const AccountRecoveryScreen({
    super.key,
    required this.accountId,
    required this.recoveryCode,
  });

  @override
  State<AccountRecoveryScreen> createState() => _AccountRecoveryScreenState();
}

class _AccountRecoveryScreenState extends State<AccountRecoveryScreen> {
  final _accountIdController = TextEditingController();
  final _codeController = TextEditingController();
  bool _codeObscured = true;

  @override
  void initState() {
    super.initState();
    // Pre-fill if values were passed via route extras
    if (widget.accountId.isNotEmpty) {
      _accountIdController.text = widget.accountId;
    }
    if (widget.recoveryCode.isNotEmpty) {
      _codeController.text = widget.recoveryCode;
      _codeObscured = false;
    }
  }

  @override
  void dispose() {
    _accountIdController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          HapticService.medium();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Аккаунт восстановлен! Установите номер/email в настройках.'),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/chats');
        } else if (state is AuthError) {
          HapticService.heavy();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: context.colors.error,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Восстановление аккаунта')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: context.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.restore, size: 32, color: context.success),
              ),
              const SizedBox(height: 24),
              Text(
                'Восстановить аккаунт?',
                style: context.typography.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Ваш аккаунт был удалён. У вас есть 30 дней для восстановления.\n'
                'Введите ID аккаунта и 8-значный код восстановления, '
                'полученный при удалении.',
                style: context.typography.bodyMedium?.copyWith(
                  color: context.colors.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Account ID field
              TextFormField(
                controller: _accountIdController,
                decoration: const InputDecoration(
                  hintText: 'ID аккаунта',
                  prefixIcon: Icon(Icons.person_outline),
                  helperText: 'Уникальный идентификатор вашего аккаунта',
                ),
              ),
              const SizedBox(height: 16),

              // Recovery code field
              TextFormField(
                controller: _codeController,
                maxLength: 8,
                textAlign: _codeObscured ? TextAlign.center : TextAlign.start,
                style: _codeObscured
                    ? context.typography.headlineLarge?.copyWith(
                        letterSpacing: 4,
                        fontWeight: FontWeight.w700,
                      )
                    : context.typography.bodyLarge?.copyWith(
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      ),
                obscureText: _codeObscured,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'XXXXXXXX',
                  hintStyle: context.typography.headlineLarge?.copyWith(
                    color: context.colors.onSurface.withOpacity(0.2),
                    letterSpacing: 4,
                  ),
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_codeObscured ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _codeObscured = !_codeObscured),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Important notice
              CharoCard(
                borderWidth: 1,
                borderColor: context.warning.withOpacity(0.3),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.info_outline, color: context.warning, size: 20),
                      const SizedBox(width: 8),
                      Text('Важно', style: context.typography.titleMedium?.copyWith(
                        color: context.warning,
                        fontWeight: FontWeight.w600,
                      )),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      '• После восстановления нужно установить новый номер/email в настройках профиля\n'
                      '• Ключи шифрования E2EE были удалены и не восстановятся\n'
                      '• Секретные чаты не могут быть восстановлены\n'
                      '• Обычные чаты и группы будут доступны',
                      style: context.typography.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Recover button
              BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  final isLoading = state is AuthLoading;
                  final canRecover = _accountIdController.text.isNotEmpty && _codeController.text.length == 8;
                  return FilledButton.icon(
                    onPressed: (isLoading || !canRecover) ? null : _onRecover,
                    icon: isLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.restore),
                    label: const Text('Восстановить аккаунт'),
                    style: FilledButton.styleFrom(
                      backgroundColor: context.success,
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Создать новый аккаунт вместо этого'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onRecover() {
    HapticService.medium();
    context.read<AuthBloc>().add(AuthAccountRecoveryRequested(
      accountId: _accountIdController.text.trim(),
      recoveryCode: _codeController.text.trim(),
    ));
  }
}
