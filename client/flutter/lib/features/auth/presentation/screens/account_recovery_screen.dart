import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
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
  final _codeController = TextEditingController();
  bool _isRecovering = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Восстановление аккаунта')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: context.colors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.restore, size: 32, color: context.colors.success),
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
              'Введите 8-значный код восстановления, который был отправлен при удалении.',
              style: context.typography.bodyMedium?.copyWith(
                color: context.colors.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Recovery code field
            TextFormField(
              controller: _codeController,
              maxLength: 8,
              textAlign: TextAlign.center,
              style: context.typography.headlineLarge?.copyWith(
                letterSpacing: 4,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'XXXXXXXX',
                hintStyle: context.typography.headlineLarge?.copyWith(
                  color: context.colors.onSurface.withOpacity(0.2),
                  letterSpacing: 4,
                ),
                prefixIcon: const Icon(Icons.vpn_key_outlined),
              ),
            ),
            const SizedBox(height: 24),

            // Important notice
            CharoCard(
              borderWidth: 1,
              borderColor: context.colors.warning.withOpacity(0.3),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.info_outline, color: context.colors.warning, size: 20),
                    const SizedBox(width: 8),
                    Text('Важно', style: context.typography.titleMedium?.copyWith(
                      color: context.colors.warning,
                      fontWeight: FontWeight.w600,
                    )),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    '• После восстановления Вам нужно будет установить новый номер/email в настройках профиля\n'
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
            FilledButton.icon(
              onPressed: _codeController.text.length == 8 ? _onRecover : null,
              icon: const Icon(Icons.restore),
              label: const Text('Восстановить аккаунт'),
              style: FilledButton.styleFrom(
                backgroundColor: context.colors.success,
              ),
            ),
            const SizedBox(height: 16),

            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Создать новый аккаунт вместо этого'),
            ),
          ],
        ),
      ),
    );
  }

  void _onRecover() {
    // In a real app, this would call the auth API's /auth/recover endpoint
    setState(() => _isRecovering = true);

    // Simulate recovery (in production: call ApiClient.post('/api/v1/auth/recover', data: {...}))
    Future.delayed(const Duration(seconds: 2), () {
      setState(() => _isRecovering = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Аккаунт восстановлен! Установите номер/email в настройках.'),
          backgroundColor: Colors.green,
        ),
      );
      context.go('/chats');
    });
  }
}
