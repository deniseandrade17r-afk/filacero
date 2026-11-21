import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/correo.dart';
import '../widgets/glass_card.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _entrada = TextEditingController();
  final _codigo = TextEditingController();
  final _nueva = TextEditingController();
  bool _codigoEnviado = false;
  bool _loading = false;
  String _correo = '';

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _enviarCodigo() async {
    if (_entrada.text.trim().isEmpty && _correo.isEmpty) {
      _msg('Ingresa tu matrícula o correo');
      return;
    }
    setState(() => _loading = true);
    try {
      if (_entrada.text.trim().isNotEmpty) {
        _correo = correoDesdeEntrada(_entrada.text);
      }
      await Supabase.instance.client.auth.resetPasswordForEmail(_correo);
      if (!mounted) return;
      setState(() => _codigoEnviado = true);
      _msg('Si la cuenta existe, te enviamos un código a tu correo institucional.');
    } on AuthException catch (e) {
      _msg(e.message);
    } catch (_) {
      _msg('No se pudo enviar el código. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cambiarContrasena() async {
    if (_codigo.text.trim().length < 6) {
      _msg('Ingresa el código que te llegó al correo');
      return;
    }
    if (_nueva.text.length < 6) {
      _msg('La contraseña debe tener mínimo 6 caracteres');
      return;
    }
    setState(() => _loading = true);
    try {
      final auth = Supabase.instance.client.auth;
      await auth.verifyOTP(
        email: _correo,
        token: _codigo.text.trim(),
        type: OtpType.recovery,
      );
      await auth.updateUser(UserAttributes(password: _nueva.text));
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
      _msg('Contraseña actualizada.');
    } on AuthException catch (e) {
      _msg(e.message);
    } catch (_) {
      _msg('No se pudo cambiar la contraseña. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: GlassCard(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_codigoEnviado) ...[
                    const Text(
                      'Te enviaremos un código a tu correo institucional.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _entrada,
                      decoration: const InputDecoration(
                        labelText: 'Matrícula o correo institucional',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _loading ? null : _enviarCodigo,
                      child: const Text('Enviar código'),
                    ),
                  ] else ...[
                    Text(
                      'Escribe el código enviado a $_correo y tu nueva contraseña.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _codigo,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Código de recuperación',
                        prefixIcon: Icon(Icons.pin_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _nueva,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Nueva contraseña (mínimo 6 caracteres)',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _loading ? null : _cambiarContrasena,
                      child: const Text('Cambiar contraseña'),
                    ),
                    TextButton(
                      onPressed: _loading ? null : _enviarCodigo,
                      child: const Text('Reenviar código'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}