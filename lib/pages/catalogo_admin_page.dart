import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'editar_tramite_page.dart';

class CatalogoAdminPage extends StatefulWidget {
  const CatalogoAdminPage({super.key});
  @override
  State<CatalogoAdminPage> createState() => _CatalogoAdminPageState();
}

class _CatalogoAdminPageState extends State<CatalogoAdminPage> {
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>> _items = [];
  bool _cargando = true;
  bool _error = false;
  String _busca = '';

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

  Future<void> _cargar() async {
    try {
      final res = await _db.from('tramites').select().order('nombre');
      if (!mounted) return;
      setState(() {
        _items = [...res];
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

  Future<void> _activar(Map<String, dynamic> t, bool v) async {
    try {
      await _db.from('tramites').update({'activo': v}).eq('id', t['id']);
      if (!mounted) return;
      setState(() => t['activo'] = v);
    } catch (_) {
      _msg('No se pudo cambiar el estado del trámite.');
    }
  }

  void _editar([Map<String, dynamic>? t]) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditarTramitePage(tramite: t)),
    ).then((_) => _cargar());
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final q = _norm(_busca.trim());
    final vista = _items
        .where((tr) => q.isEmpty || _norm(tr['nombre']).contains(q))
        .toList();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(children: [
          Expanded(
            child: Text('Catálogo de trámites',
                style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          ),
          ElevatedButton.icon(
            onPressed: () => _editar(),
            icon: const Icon(Icons.add),
            label: const Text('Nuevo'),
          ),
        ]),
        const SizedBox(height: 16),
        TextField(
          onChanged: (v) => setState(() => _busca = v),
          decoration: const InputDecoration(
            hintText: 'Buscar trámite',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 16),
        if (_cargando)
          const Center(child: CircularProgressIndicator())
        else if (_error)
          const GlassCard(child: Text('No se pudo cargar el catálogo.'))
        else if (vista.isEmpty)
          const GlassCard(child: Text('No hay trámites con ese nombre.'))
        else
          for (final tr in vista)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                onTap: () => _editar(tr),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.yellow.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      tr['modalidad'] == 'presencial'
                          ? Icons.apartment_rounded
                          : Icons.laptop_mac_rounded,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr['nombre'],
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                        Text(tr['modalidad'] == 'presencial'
                            ? 'Presencial (con cita)'
                            : 'En línea'),
                        if (tr['activo'] != true)
                          const Text('Inactivo: no se muestra a los alumnos',
                              style: TextStyle(
                                  color: AppColors.red,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12)),
                      ],
                    ),
                  ),
                  Switch(
                    value: tr['activo'] == true,
                    onChanged: (v) => _activar(tr, v),
                  ),
                  const Icon(Icons.chevron_right),
                ]),
              ),
            ),
      ],
    );
  }
}