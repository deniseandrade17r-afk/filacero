import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../utils/fechas.dart';
import '../widgets/glass_card.dart';
import 'documentos_page.dart';
import '../widgets/formato_tile.dart';

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
  DateTime? _desde;
  DateTime? _hasta;

  bool get _pideFechas => widget.tramite['pide_fechas'] == true;

  String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _elegirFecha(bool esDesde) async {
    final hoy = DateTime.now();
    final f = await showDatePicker(
      context: context,
      initialDate: (esDesde ? _desde : _hasta) ?? hoy,
      firstDate: hoy.subtract(const Duration(days: 60)),
      lastDate: hoy,
    );
    if (f == null) return;
    setState(() {
      if (esDesde) {
        _desde = f;
        if (_hasta != null && _hasta!.isBefore(f)) _hasta = f;
      } else {
        _hasta = f;
        if (_desde != null && f.isBefore(_desde!)) _desde = f;
      }
    });
  }

  Future<void> _crear() async {
    if (!_form.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    if (_pideFechas && (_desde == null || _hasta == null)) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Indica desde y hasta qué fecha faltaste.')));
      return;
    }
    setState(() => _loading = true);
    try {
      final db = Supabase.instance.client;
      final fila = await db
          .from('solicitudes')
          .insert({
            'alumno_id': db.auth.currentUser!.id,
            'tramite_id': widget.tramite['id'],
            'motivo': _motivo.text.trim(),
            if (_pideFechas) 'fecha_desde': _iso(_desde!),
            if (_pideFechas) 'fecha_hasta': _iso(_hasta!),
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

  List<String> _lista(dynamic v) => ((v as List?) ?? []).cast<String>();

  Widget _titulo(String t) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(t,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      );

  List<Widget> _pasos(List<String> pasos) {
    final out = <Widget>[];
    var n = 0;
    for (final p in pasos) {
      if (p.startsWith('## ')) {
        n = 0;
        out.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(p.substring(3),
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.navy)),
        ));
      } else {
        n++;
        out.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                  width: 26,
                  child: Text('$n.',
                      style: const TextStyle(fontWeight: FontWeight.w700))),
              Expanded(child: Text(p)),
            ],
          ),
        ));
      }
    }
    return out;
  }

  Widget _vinetas(List<String> items, IconData icono) => Column(
        children: [
          for (final r in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icono, size: 20, color: AppColors.navy),
                  const SizedBox(width: 8),
                  Expanded(child: Text(r)),
                ],
              ),
            ),
        ],
      );

  Widget _campoFecha(String etiqueta, DateTime? valor, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: etiqueta,
            prefixIcon: const Icon(Icons.calendar_today_outlined),
          ),
          child: Text(valor == null
              ? 'Elegir fecha'
              : '${fechaLarga(valor)} ${valor.year}'),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final tr = widget.tramite;
    final reqs = _lista(tr['requisitos']);
    final pasos = _lista(tr['pasos']);
    final obs = _lista(tr['observaciones']);
    final formatos = ((tr['formatos'] as List?) ?? [])
        .map((f) => (f as Map)['nombre'].toString())
        .toList();
    final presencial = tr['modalidad'] == 'presencial';

    return Scaffold(
      appBar: AppBar(title: Text(tr['nombre'])),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
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
                    if (pasos.isNotEmpty) ...[
                      _titulo('Pasos a seguir'),
                      ..._pasos(pasos),
                    ],
                    if (obs.isNotEmpty) ...[
                      _titulo('Observaciones'),
                      _vinetas(obs, Icons.info_outline),
                    ],
                    if (formatos.isNotEmpty) ...[
                      _titulo('Formatos (PDF)'),
                      _vinetas(formatos, Icons.picture_as_pdf_outlined),
                    ],
                    if (reqs.isNotEmpty) ...[
                      _titulo('Lo que necesitas para tu solicitud'),
                      _vinetas(reqs, Icons.check_circle_outline),
                    ],
                    if (_pideFechas) ...[
                      _titulo('Fechas de inasistencia'),
                      _campoFecha('Desde', _desde, () => _elegirFecha(true)),
                      const SizedBox(height: 12),
                      _campoFecha('Hasta', _hasta, () => _elegirFecha(false)),
                    ],
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