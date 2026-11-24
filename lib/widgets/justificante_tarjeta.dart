import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import 'glass_card.dart';

class JustificanteTarjeta extends StatefulWidget {
  const JustificanteTarjeta({super.key, required this.solicitudId});
  final dynamic solicitudId;
  @override
  State<JustificanteTarjeta> createState() => _JustificanteTarjetaState();
}

class _JustificanteTarjetaState extends State<JustificanteTarjeta> {
  final _db = Supabase.instance.client;
  Map<String, dynamic>? _j;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = await _db
          .from('justificantes')
          .select('folio, ruta')
          .eq('solicitud_id', widget.solicitudId)
          .maybeSingle();
      if (!mounted) return;
      setState(() => _j = r);
    } catch (_) {}
  }

  Future<void> _abrir() async {
    try {
      final url = await _db.storage
          .from('documentos')
          .createSignedUrl(_j!['ruta'] as String, 300);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el justificante.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final j = _j;
    if (j == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          const Icon(Icons.description_rounded, color: AppColors.navy, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Justificante emitido',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text('Folio ${j['folio']}'),
              ],
            ),
          ),
          ElevatedButton(onPressed: _abrir, child: const Text('Descargar')),
        ]),
      ),
    );
  }
}