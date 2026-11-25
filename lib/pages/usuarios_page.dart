import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class UsuariosPage extends StatefulWidget {
  const UsuariosPage({super.key});
  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  final _db = Supabase.instance.client;
  late final String? _yo = _db.auth.currentUser?.id;

  List<Map<String, dynamic>> _usuarios = [];
  List<Map<String, dynamic>> _personal = [];
  bool _cargando = true;
  bool _error = false;
  String _vista = 'usuarios';
  String _filtro = 'todos';
  String _busca = '';
  final _emailAut = TextEditingController();
  String _rolAut = 'coordinador';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _msg(String t) {
    if (!mounted) return;
    mostrarAviso(context, t);
  }

  String _norm(String s) => s
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n');

  String _rolLabel(String r) {
    switch (r) {
      case 'admin':
        return 'Administrador';
      case 'coordinador':
        return 'Coordinador';
      default:
        return 'Alumno';
    }
  }

  Color _rolColor(String r) {
    switch (r) {
      case 'admin':
        return AppColors.red;
      case 'coordinador':
        return AppColors.navy;
      default:
        return Colors.blueGrey;
    }
  }

  Future<void> _cargar() async {
    try {
      final us = await _db.rpc('listar_usuarios') as List;
      final pe = await _db.from('personal_autorizado').select().order('email');
      if (!mounted) return;
      setState(() {
        _usuarios = us.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _personal = [...pe];
        _cargando = false;
        _error = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = true;
      });
    }
  }

  Future<void> _llamar(String fn, Map<String, dynamic> params, String ok) async {
    try {
      await _db.rpc(fn, params: params);
      _msg(ok);
    } on PostgrestException catch (e) {
      _msg(e.code == '23503'
          ? 'Este usuario tiene registros (solicitudes, citas o justificantes). '
              'Desactívalo en lugar de eliminarlo.'
          : e.message);
    } catch (_) {
      _msg('No se pudo completar la acción.');
    }
    await _cargar();
  }

  Future<void> _cambiarRol(Map<String, dynamic> u) async {
    final actual = u['rol'] as String;
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Rol de ${u['nombre']}'),
        children: [
          for (final r in const ['alumno', 'coordinador', 'admin'])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, r),
              child: Text(r == actual
                  ? '${_rolLabel(r)} (actual)'
                  : _rolLabel(r)),
            ),
        ],
      ),
    );
    if (r == null || r == actual) return;
    await _llamar('cambiar_rol', {'p_usuario': u['id'], 'p_rol': r},
        'Rol actualizado. La persona debe volver a iniciar sesión.');
  }

  Future<void> _editar(Map<String, dynamic> u) async {
    final nombre = TextEditingController(text: u['nombre'] ?? '');
    final carrera = TextEditingController(text: u['carrera'] ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Editar datos'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: nombre,
                decoration: const InputDecoration(labelText: 'Nombre completo')),
            const SizedBox(height: 12),
            TextField(
                controller: carrera,
                decoration: const InputDecoration(labelText: 'Carrera')),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Guardar')),
        ],
      ),
    );
    if (ok != true) return;
    await _llamar(
        'editar_usuario',
        {
          'p_usuario': u['id'],
          'p_nombre': nombre.text,
          'p_carrera': carrera.text,
        },
        'Datos actualizados.');
  }

  Future<void> _eliminar(Map<String, dynamic> u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text(
            'Se eliminará la cuenta de ${u['nombre']}. Solo es posible si no '
            'tiene solicitudes, citas ni justificantes. Esta acción no se '
            'puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    await _llamar('eliminar_usuario', {'p_usuario': u['id']}, 'Usuario eliminado.');
  }

  Future<void> _accion(String a, Map<String, dynamic> u) async {
    switch (a) {
      case 'rol':
        await _cambiarRol(u);
        break;
      case 'editar':
        await _editar(u);
        break;
      case 'estado':
        final activar = u['activo'] != true;
        await _llamar(
            'cambiar_estado_usuario',
            {'p_usuario': u['id'], 'p_activo': activar},
            activar ? 'Cuenta activada.' : 'Cuenta desactivada.');
        break;
      case 'eliminar':
        await _eliminar(u);
        break;
    }
  }

  Future<void> _autorizar() async {
    final email = _emailAut.text.trim().toLowerCase();
    if (!email.endsWith('@unison.mx') || email.length < 12) {
      _msg('Escribe un correo institucional @unison.mx.');
      return;
    }
    final existente = _usuarios
        .where((u) => (u['email'] ?? '').toString().toLowerCase() == email)
        .toList();
    try {
      if (existente.isNotEmpty) {
        await _db.rpc('cambiar_rol',
            params: {'p_usuario': existente.first['id'], 'p_rol': _rolAut});
        _msg('Ese correo ya tenía cuenta: se le asignó el rol.');
      } else {
        await _db.from('personal_autorizado').upsert({'email': email, 'rol': _rolAut});
        _msg('Correo autorizado. Ya puede registrarse.');
      }
      _emailAut.clear();
    } on PostgrestException catch (e) {
      _msg(e.message);
    } catch (_) {
      _msg('No se pudo autorizar el correo.');
    }
    await _cargar();
  }

  Future<void> _quitarAutorizacion(String email) async {
    try {
      await _db.from('personal_autorizado').delete().eq('email', email);
      _msg('Autorización retirada. Las cuentas ya creadas no se modifican.');
    } catch (_) {
      _msg('No se pudo retirar la autorización.');
    }
    await _cargar();
  }

  Widget _chip(String texto, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(texto,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 12)),
      );

  Widget _tarjetaUsuario(Map<String, dynamic> u) {
    final esYo = u['id'] == _yo;
    final activo = u['activo'] == true;
    final rol = u['rol'] as String;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${u['nombre'] ?? '-'}${esYo ? ' (tú)' : ''}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: activo ? AppColors.ink : Colors.blueGrey)),
                Text('${u['email'] ?? ''}'),
                if ((u['matricula'] ?? '').toString().isNotEmpty)
                  Text('Matrícula ${u['matricula']}',
                      style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _chip(_rolLabel(rol), _rolColor(rol)),
                  if (!activo) _chip('Inactivo', AppColors.red),
                ]),
              ],
            ),
          ),
          if (!esYo)
            PopupMenuButton<String>(
              tooltip: 'Acciones',
              onSelected: (a) => _accion(a, u),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'rol', child: Text('Cambiar rol')),
                const PopupMenuItem(
                    value: 'editar', child: Text('Editar datos')),
                PopupMenuItem(
                    value: 'estado',
                    child: Text(activo ? 'Desactivar cuenta' : 'Activar cuenta')),
                const PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
              ],
            )
          else
            PopupMenuButton<String>(
              tooltip: 'Acciones',
              onSelected: (a) => _accion(a, u),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'editar', child: Text('Editar datos')),
              ],
            ),
        ]),
      ),
    );
  }

  Widget _vistaUsuarios() {
    final q = _norm(_busca.trim());
    final lista = _usuarios.where((u) {
      final coincideRol = _filtro == 'todos' || u['rol'] == _filtro;
      final texto = _norm(
          '${u['nombre'] ?? ''} ${u['email'] ?? ''} ${u['matricula'] ?? ''}');
      return coincideRol && (q.isEmpty || texto.contains(q));
    }).toList();

    const filtros = {
      'todos': 'Todos',
      'alumno': 'Alumnos',
      'coordinador': 'Coordinadores',
      'admin': 'Administradores',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          onChanged: (v) => setState(() => _busca = v),
          decoration: const InputDecoration(
            hintText: 'Buscar por nombre, correo o matrícula',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in filtros.entries)
            ChoiceChip(
              label: Text(e.value),
              selected: _filtro == e.key,
              onSelected: (_) => setState(() => _filtro = e.key),
            ),
        ]),
        const SizedBox(height: 16),
        if (lista.isEmpty)
          const GlassCard(child: Text('No hay usuarios con esos criterios.'))
        else
          for (final u in lista) _tarjetaUsuario(u),
      ],
    );
  }

  Widget _vistaPersonal() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Autorizar personal',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 4),
              const Text(
                  'Solo los correos autorizados pueden registrarse como '
                  'coordinador o administrador.',
                  style: TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              TextField(
                controller: _emailAut,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo institucional',
                  hintText: 'nombre.apellido@unison.mx',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'coordinador', label: Text('Coordinador')),
                  ButtonSegment(value: 'admin', label: Text('Administrador')),
                ],
                selected: {_rolAut},
                onSelectionChanged: (s) => setState(() => _rolAut = s.first),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                  onPressed: _autorizar, child: const Text('Autorizar')),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_personal.isEmpty)
          const GlassCard(child: Text('Aún no hay correos autorizados.'))
        else
          for (final p in _personal)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${p['email']}',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        _chip(_rolLabel(p['rol']), _rolColor(p['rol'])),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Quitar autorización',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _quitarAutorizacion(p['email']),
                  ),
                ]),
              ),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(children: [
          Expanded(
            child: Text('Usuarios y roles',
                style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          ),
          IconButton(
              tooltip: 'Actualizar',
              icon: const Icon(Icons.refresh),
              onPressed: _cargar),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ChoiceChip(
            label: Text('Usuarios (${_usuarios.length})'),
            selected: _vista == 'usuarios',
            onSelected: (_) => setState(() => _vista = 'usuarios'),
          ),
          ChoiceChip(
            label: Text('Personal autorizado (${_personal.length})'),
            selected: _vista == 'personal',
            onSelected: (_) => setState(() => _vista = 'personal'),
          ),
        ]),
        const SizedBox(height: 16),
        if (_cargando)
          const Center(child: CircularProgressIndicator())
        else if (_error)
          const GlassCard(child: Text('No se pudieron cargar los usuarios.'))
        else if (_vista == 'usuarios')
          _vistaUsuarios()
        else
          _vistaPersonal(),
      ],
    );
  }
}