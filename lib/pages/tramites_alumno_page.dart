import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'solicitar_tramite_page.dart';

class TramitesAlumnoPage extends StatefulWidget {
  const TramitesAlumnoPage({super.key});
  @override
  State<TramitesAlumnoPage> createState() => _TramitesAlumnoPageState();
}

class _TramitesAlumnoPageState extends State<TramitesAlumnoPage> {
  String _busca = '';
  late final Future<List<Map<String, dynamic>>> _tramites = Supabase
      .instance.client
      .from('tramites')
      .select()
      .eq('activo', true)
      .order('nombre');

  String _norm(String s) => s
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n');

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('¿Qué trámite necesitas?',
            style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        TextField(
          onChanged: (v) => setState(() => _busca = v),
          decoration: const InputDecoration(
            hintText: 'Buscar trámite',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _tramites,
          builder: (context, snap) {
            if (snap.hasError) return const Text('No se pudo cargar el catálogo.');
            if (!snap.hasData) {
              return const Center(
                  child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator()));
            }
            final q = _norm(_busca.trim());
            final lista = snap.data!
                .where((tr) => q.isEmpty || _norm(tr['nombre']).contains(q))
                .toList();
            if (lista.isEmpty) {
              return const GlassCard(
                  child: Text('No encontramos trámites con ese nombre.'));
            }
            return LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth >= 900 ? 3 : (c.maxWidth >= 600 ? 2 : 1);
              final w = (c.maxWidth - (cols - 1) * 16) / cols;
              return Wrap(spacing: 16, runSpacing: 16, children: [
                for (final tr in lista)
                  SizedBox(
                    width: w,
                    child: GlassCard(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => SolicitarTramitePage(tramite: tr)),
                      ),
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
                              const SizedBox(height: 2),
                              Text(tr['modalidad'] == 'presencial'
                                  ? 'Presencial (con cita)'
                                  : 'En línea'),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ]),
                    ),
                  ),
              ]);
            });
          },
        ),
      ],
    );
  }
}