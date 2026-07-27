import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../bloc/auth_bloc.dart';

/// Экран верификации OTP-кода
class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());
  Timer? _resendTimer;
  int _resendSeconds = 120;
  late String _identifier;
  late String _method;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Получаем данные из router extra
    final extra = GoRouterState.of(context).extra;
    if (extra != null && extra is Map<String, dynamic>) {
      _identifier = extra['identifier'] as String? ?? '';
      _method = extra['method'] as String? ?? 'phone';
    } else {
      _identifier = '';
      _method = 'phone';
    }
    _startResendTimer();
  }

  void _startResendTimer() {
    _resendSeconds = 120;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _resendSeconds--;
        if (_resendSeconds <= 0) {
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go('/chats');
        }
        if (state is Auth2faRequired) {
          context.go('/2fa', extra: {
            'tempToken': state.tempToken,
            'identifier': state.identifier,
          });
        }
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: context.colors.error),
          );
          // Очистка полей при ошибке
          for (final c in _controllers) { c.clear(); }
          _focusNodes[0].requestFocus();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Подтверждение')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Icon(Icons.sms_outlined, size: 64, color: context.colors.primary),
              const SizedBox(height: 24),
              Text(
                'Введите код',
                style: context.typography.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Мы отправили 6-значный код на\n${_maskIdentifier(_identifier)}',
                style: context.typography.bodyMedium?.copyWith(
                  color: context.colors.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // 6 полей OTP
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) => _buildOtpField(index)),
              ),
              const SizedBox(height: 32),

              // Кнопка проверки
              BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  final isLoading = state is AuthLoading;
                  return FilledButton(
                    onPressed: (_code.length == 6 && !isLoading) ? _onVerify : null,
                    child: isLoading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Подтвердить'),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Повторная отправка
              if (_resendSeconds > 0)
                Text(
                  'Повторная отправка через ${_resendSeconds ~/ 60}:${(_resendSeconds % 60).toString().padLeft(2, '0')}',
                  style: context.typography.bodyMedium?.copyWith(
                    color: context.colors.onSurface.withOpacity(0.5),
                  ),
                  textAlign: TextAlign.center,
                )
              else
                TextButton(
                  onPressed: () {
                    context.read<AuthBloc>().add(AuthLoginRequested(
                          identifier: _identifier,
                          method: _method,
                        ));
                    _startResendTimer();
                  },
                  child: const Text('Отправить код повторно'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpField(int index) {
    return SizedBox(
      width: 48,
      height: 56,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: context.typography.headlineLarge,
        decoration: InputDecoration(
          counterText: '',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.colors.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.colors.primary, width: 2),
          ),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          }
          // Автоматическая верификация при вводе последней цифры
          if (index == 5 && _code.length == 6) {
            _onVerify();
          }
        },
      ),
    );
  }

  void _onVerify() {
    if (_code.length != 6) return;
    context.read<AuthBloc>().add(AuthOtpSubmitted(
          identifier: _identifier,
          code: _code,
          method: _method,
        ));
  }

  String _maskIdentifier(String id) {
    if (id.contains('@')) {
      final parts = id.split('@');
      return '${parts[0][0]}***@${parts[1]}';
    }
    if (id.length > 4) {
      return '${id.substring(0, 2)}***${id.substring(id.length - 2)}';
    }
    return id;
  }
}
