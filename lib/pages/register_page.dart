import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/glass_card.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _password = TextEditingController();
  final _codigo = TextEditingController();
  bool _loading = false;
  bool _pendiente = false; // ya se registró y falta el código
  String _correoRegistrado = '';

  void _msg(String text) {
    if (!mounted) return;
    mostrarAviso(context, text);
  }

  Future<void> _registrar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final correo = _correo.text.trim().toLowerCase();
      final res = await Supabase.instance.client.auth.signUp(
        email: correo,
        password: _password.text,
        data: {'nombre': _nombre.text.trim()},
      );
      if (!mounted) return;
      if (res.session != null) {
        // La confirmación está desactivada: ya inició sesión
        Navigator.of(context).popUntil((r) => r.isFirst);
        return;
      }
      setState(() {
        _pendiente = true;
        _correoRegistrado = correo;
      });
      _msg('Te enviamos un código a tu correo institucional.');
    } on AuthException catch (e) {
      _msg(e.message);
    } catch (_) {
      _msg('No se pudo crear la cuenta. Alumnos: usa aMATRICULA@unison.mx. '
          'Personal: pide al administrador que autorice tu correo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmar() async {
    if (_codigo.text.trim().length < 6) {
      _msg('Escribe el código que te llegó al correo.');
      return;
    }
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: _correoRegistrado,
        token: _codigo.text.trim(),
        type: OtpType.signup,
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } on AuthException catch (e) {
      _msg(e.message);
    } catch (_) {
      _msg('No se pudo confirmar la cuenta. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reenviar() async {
    try {
      await Supabase.instance.client.auth
          .resend(type: OtpType.signup, email: _correoRegistrado);
      _msg('Te enviamos un nuevo código.');
    } on AuthException catch (e) {
      _msg(e.message);
    } catch (_) {
      _msg('No se pudo reenviar el código.');
    }
  }

  Widget _formularioRegistro() {
    return Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _nombre,
            decoration: const InputDecoration(
              labelText: 'Nombre completo',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _correo,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Correo institucional',
              hintText: 'a123456789@unison.mx',
              prefixIcon: Icon(Icons.mail_outline),
            ),
            validator: (v) => (v ?? '').trim().toLowerCase().endsWith('@unison.mx')
                ? null
                : 'Usa tu correo institucional @unison.mx',
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Contraseña (mínimo 6 caracteres)',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: (v) =>
                (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _loading ? null : _registrar,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Registrarme'),
          ),
        ],
      ),
    );
  }

  Widget _formularioCodigo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Escribe el código que enviamos a $_correoRegistrado para '
            'confirmar tu cuenta.',
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        TextField(
          controller: _codigo,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Código de confirmación',
            prefixIcon: Icon(Icons.pin_outlined),
          ),
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: _loading ? null : _confirmar,
          child: _loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Confirmar cuenta'),
        ),
        TextButton(
          onPressed: _loading ? null : _reenviar,
          child: const Text('Reenviar código'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: GlassCard(
              padding: const EdgeInsets.all(28),
              child: _pendiente ? _formularioCodigo() : _formularioRegistro(),
            ),
          ),
        ),
      ),
    );
  }
}