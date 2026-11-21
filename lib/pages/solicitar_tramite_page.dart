import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'documentos_page.dart';

class SolicitarTramitePage extends StatefulWidget {
  const SolicitarTramitePage({super.key, required this.tramite});
  final Map<String, dynamic> tramite;
  @override
  State<SolicitarTramitePage> createState() => _SolicitarTramitePageState();
}

class _SolicitarTramitePageState extends State<SolicitarTramitePage> {
  final _form = GlobalKey<FormState>();
  final _motivo = TextEditingController();
  bool _loading = false;

  Future<void> _crear() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final db = Supabase.instance.client;
      final fila = await db
          .from('solicitudes')
          .insert({
            'alumno_id': db.auth.currentUser!.id,
            'tramite_id': widget.tramite['id'],
            'motivo': _motivo.text.trim(),
          })
          .select('id')
          .single();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentosPage(solicitudId: fila['id']),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No se pudo crear la solicitud. Intenta de nuevo.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = widget.tramite;
    final reqs = ((tr['requisitos'] as List?) ?? []).cast<String>();
    final presencial = tr['modalidad'] == 'presencial';

    return Scaffold(
      appBar: AppBar(title: Text(tr['nombre'])),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: GlassCard(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((tr['descripcion'] ?? '').toString().isNotEmpty) ...[
                      Text(tr['descripcion']),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      presencial
                          ? 'Modalidad: presencial (necesitarás agendar una cita)'
                          : 'Modalidad: en línea',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Requisitos',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final r in reqs)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              size: 20,
                              color: AppColors.navy,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(r)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _motivo,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Motivo de tu solicitud',
                        alignLabelWithHint: true,
                      ),
                      validator: (v) => (v == null || v.trim().length < 5)
                          ? 'Cuéntanos brevemente el motivo'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.yellow.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Después podrás subir tus documentos. La solicitud '
                              'quedará como borrador hasta que estén completos.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _loading ? null : _crear,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Crear solicitud'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
