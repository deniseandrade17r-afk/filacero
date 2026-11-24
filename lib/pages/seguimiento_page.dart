import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../utils/estados.dart';
import '../widgets/glass_card.dart';
import 'detalle_solicitud_page.dart';
import 'documentos_page.dart';

class SeguimientoPage extends StatefulWidget {
  const SeguimientoPage({super.key});
  @override
  State<SeguimientoPage> createState() => _SeguimientoPageState();
}

class _SeguimientoPageState extends State<SeguimientoPage> {
  final _db = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _f = _cargar();

  Future<List<Map<String, dynamic>>> _cargar() => _db
      .from('solicitudes')
      .select(
          'id, estado, motivo, observacion, created_at, tramites(nombre, modalidad)')
      .eq('alumno_id', _db.auth.currentUser!.id)
      .order('created_at', ascending: false);

  void _recargar() {
    setState(() {
      _f = _cargar();
    });
  }

  Future<void> _borrar(dynamic id) async {
    try {
      final docs = await _db
          .from('documentos')
          .select('ruta')
          .eq('solicitud_id', id);
      final rutas = [for (final d in docs) d['ruta'] as String];
      if (rutas.isNotEmpty) await _db.storage.from('documentos').remove(rutas);
    } catch (_) {}
    await _db.from('solicitudes').delete().eq('id', id);
    if (!mounted) return;
    _recargar();
  }

  String _fecha(String iso) {
    final d = DateTime.parse(iso).toLocal();
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Mis solicitudes',
                style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Actualizar',
              icon: const Icon(Icons.refresh),
              onPressed: _recargar,
            ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _f,
          builder: (context, snap) {
            if (snap.hasError) {
              return const Text('No se pudieron cargar tus solicitudes.');
            }
            if (!snap.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            final lista = snap.data!;
            if (lista.isEmpty) {
              return const GlassCard(
                child: Text(
                  'Aún no tienes solicitudes. Ve a Trámites para crear la primera.',
                ),
              );
            }
            return Column(
              children: [
                for (final s in lista)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: GlassCard(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              DetalleSolicitudPage(solicitudId: s['id']),
                        ),
                      ).then((_) => _recargar()),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s['tramites']['nombre'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  s['motivo'] ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _fecha(s['created_at']),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                if (s['estado'] == 'requiere_correccion' &&
                                    (s['observacion'] ?? '')
                                        .toString()
                                        .isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Corrección pedida: ${s['observacion']}',
                                      style: const TextStyle(
                                        color: AppColors.red,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: estadoColor(s['estado'])
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              estadoLabel(s['estado']),
                              style: TextStyle(
                                color: estadoColor(s['estado']),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (s['estado'] == 'borrador' ||
                              s['estado'] == 'requiere_correccion')
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      DocumentosPage(solicitudId: s['id']),
                                ),
                              ).then((_) => _recargar()),
                              child: const Text('Documentos'),
                            ),
                          if (s['estado'] == 'borrador')
                            IconButton(
                              tooltip: 'Eliminar borrador',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _borrar(s['id']),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}