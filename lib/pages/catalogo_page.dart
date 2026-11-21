import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class CatalogoPage extends StatefulWidget {
  const CatalogoPage({super.key, required this.titulo, this.saludo = false});
  final String titulo;
  final bool saludo;
  @override
  State<CatalogoPage> createState() => _CatalogoPageState();
}

class _CatalogoPageState extends State<CatalogoPage> {
  final _db = Supabase.instance.client;
  late final Future<List<Map<String, dynamic>>> _tramites =
      _db.from('tramites').select().order('nombre');
  late final Future<Map<String, dynamic>> _perfil =
      _db.from('profiles').select().eq('id', _db.auth.currentUser!.id).single();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (widget.saludo)
          FutureBuilder<Map<String, dynamic>>(
            future: _perfil,
            builder: (_, s) => Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                s.hasData ? '¡Hola, ${s.data!['nombre']}!' : '¡Hola!',
                style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        Text(widget.titulo,
            style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
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
            return LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth >= 900 ? 3 : (c.maxWidth >= 600 ? 2 : 1);
              final w = (c.maxWidth - (cols - 1) * 16) / cols;
              return Wrap(spacing: 16, runSpacing: 16, children: [
                for (final tr in snap.data!)
                  SizedBox(
                    width: w,
                    child: GlassCard(
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