import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/glass_card.dart';

class MiCuentaPage extends StatefulWidget {
  const MiCuentaPage({super.key});
  @override
  State<MiCuentaPage> createState() => _MiCuentaPageState();
}

class _MiCuentaPageState extends State<MiCuentaPage> {
  final _db = Supabase.instance.client;
  final _form = GlobalKey<FormState>();
  final _nueva = TextEditingController();
  final _confirma = TextEditingController();
  Map<String, dynamic>? _perfil;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _msg(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _cargar() async {
    try {
      final p = await _db
          .from('profiles')
          .select()
          .eq('id', _db.auth.currentUser!.id)
          .single();
      if (!mounted) return;
      setState(() => _perfil = p);
    } catch (_) {}
  }

  String _rol(String? r) {
    switch (r) {
      case 'admin':
        return 'Administrador';
      case 'coordinador':
        return 'Coordinador';
      default:
        return 'Alumno';
    }
  }

  Future<void> _cambiarPassword() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await _db.auth.updateUser(UserAttributes(password: _nueva.text));
      _nueva.clear();
      _confirma.clear();
      _msg('Contraseña actualizada.');
    } on AuthException catch (e) {
      _msg(e.message);
    } catch (_) {
      _msg('No se pudo cambiar la contraseña.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _salir() async {
    await _db.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Widget _dato(String etiqueta, String valor) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 110,
                child: Text(etiqueta,
                    style: const TextStyle(fontWeight: FontWeight.w700))),
            Expanded(child: Text(valor)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = _perfil;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: p == null
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _dato('Nombre', '${p['nombre'] ?? '-'}'),
                            _dato('Correo', _db.auth.currentUser?.email ?? '-'),
                            if ((p['matricula'] ?? '').toString().isNotEmpty)
                              _dato('Matrícula', '${p['matricula']}'),
                            _dato('Carrera', '${p['carrera'] ?? '-'}'),
                            _dato('Rol', _rol(p['rol'])),
                          ],
                        ),
                ),
                const SizedBox(height: 16),
                GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Cambiar contraseña',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16)),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _nueva,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Nueva contraseña (mínimo 6 caracteres)',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          validator: (v) => (v == null || v.length < 6)
                              ? 'Mínimo 6 caracteres'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirma,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Confirma la contraseña',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          validator: (v) => v != _nueva.text
                              ? 'Las contraseñas no coinciden'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _guardando ? null : _cambiarPassword,
                          child: const Text('Guardar contraseña'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: _salir,
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar sesión'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}