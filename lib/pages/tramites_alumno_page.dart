import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/glass_card.dart';
import '../widgets/tramites_grid.dart';
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
            return TramitesGrid(
              tramites: lista,
              onTap: (tr) => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => SolicitarTramitePage(tramite: tr)),
              ),
            );
          },
        ),
      ],
    );
  }
}