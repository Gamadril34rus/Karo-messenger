import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/haptic/haptic_service.dart';
import '../../../../shared/widgets/charo_widgets.dart';
import '../bloc/auth_bloc.dart';

/// Экран верификации 2FA (TOTP-код) — показывается после OTP,
/// если у пользователя включена двухфакторная аутентификация
class TwoFaVerificationScreen extends StatefulWidget {
  const TwoFaVerificationScreen({super.key});

  @override
  State<TwoFaVerificationScreen> createState() => _TwoFaVerificationScreenState();
}

class _TwoFaVerificationScreenState extends State<TwoFaVerificationScreen> {
  final _codeController = TextEditingController();
  late String _tempToken;
  late String _identifier;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra;
    if (extra != null && extra is Map<String, dynamic>) {
      _tempToken = extra['tempToken'] as String? ?? '';
      _identifier = extra['identifier'] as String? ?? '';
    } else {
      _tempToken = '';
      _identifier = '';
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          HapticService.medium();
          context.go('/chats');
        } else if (state is AuthError) {
          HapticService.heavy();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: context.colors.error),
          );
          _codeController.clear();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Двухфакторная аутентификация')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),

              // Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.shield_outlined, color: Color(0xFF8B5CF6), size: 40),
              ),
              const SizedBox(height: 24),

              Text(
                'Введите код 2FA',
                style: context.typography.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Откройте приложение-аутентификатор (Google Authenticator, Authy) '
                'и введите 6-значный TOTP-код для аккаунта ЧАРО.',
                style: context.typography.bodyMedium?.copyWith(
                  color: context.colors.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // TOTP code input
              TextFormField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: context.typography.headlineLarge?.copyWith(
                  letterSpacing: 8,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '000000',
                  hintStyle: context.typography.headlineLarge?.copyWith(
                    color: context.colors.onSurface.withOpacity(0.2),
                    letterSpacing: 8,
                  ),
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 24),

              // Verify button
              BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  final isLoading = state is AuthLoading;
                  final canVerify = _codeController.text.length == 6;
                  return FilledButton.icon(
                    onPressed: (isLoading || !canVerify) ? null : _onVerify,
                    icon: isLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.shield_check_outlined),
                    label: const Text('Подтвердить'),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Recovery codes info
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
                      Text('Коды восстановления', style: context.typography.titleMedium?.copyWith(
                        color: context.colors.warning,
                        fontWeight: FontWeight.w600,
                      )),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      'Если вы потеряли устройство с аутентификатором, '
                      'введите один из 8 резервных кодов восстановления '
                      '(8-значный код из шестнадцатеричных символов).',
                      style: context.typography.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Войти другим способом'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onVerify() {
    HapticService.medium();
    context.read<AuthBloc>().add(Auth2faVerifyRequested(
      tempToken: _tempToken,
      code: _codeController.text.trim(),
    ));
  }
}
