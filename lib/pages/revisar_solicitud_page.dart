import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../utils/estados.dart';
import '../utils/fechas.dart';
import '../utils/justificante_pdf.dart';
import '../widgets/glass_card.dart';
import '../widgets/justificante_tarjeta.dart';

class RevisarSolicitudPage extends StatefulWidget {
  const RevisarSolicitudPage({super.key, required this.solicitudId});
  final dynamic solicitudId;
  @override
  State<RevisarSolicitudPage> createState() => _RevisarSolicitudPageState();
}

class _RevisarSolicitudPageState extends State<RevisarSolicitudPage> {
  final _db = Supabase.instance.client;
  Map<String, dynamic> _sol = {};
  Map<String, Map<String, dynamic>> _docs = {};
  List<Map<String, dynamic>> _hist = [];
  bool _cargando = true;
  bool _trabajando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _msg(String t) {
    if (!mounted) return;
    mostrarAviso(context, t);
  }

  Future<void> _cargar() async {
    final sol = await _db
        .from('solicitudes')
        .select(
            'id, estado, motivo, observacion, created_at, fecha_desde, fecha_hasta, profiles(nombre, matricula), tramites(nombre, modalidad, emite_documento, documentos, documentos_opcionales)')
        .eq('id', widget.solicitudId)
        .single();
    final docs = await _db
        .from('documentos')
        .select()
        .eq('solicitud_id', widget.solicitudId);
    final hist = await _db
        .from('historial_solicitud')
        .select('estado, observacion, created_at')
        .eq('solicitud_id', widget.solicitudId)
        .order('created_at');
    if (!mounted) return;
    setState(() {
      _sol = sol;
      _docs = {for (final d in docs) d['requisito'] as String: d};
      _hist = [...hist];
      _cargando = false;
    });
  }

  Future<void> _ver(Map<String, dynamic> doc) async {
    try {
      final url = await _db.storage
          .from('documentos')
          .createSignedUrl(doc['ruta'] as String, 300);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      _msg('No se pudo abrir el documento.');
    }
  }

  Future<String?> _pedirMotivo(String titulo) async {
    final c = TextEditingController();
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: TextField(
          controller: c,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Escribe el motivo'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Enviar')),
        ],
      ),
    );
    if (r == null) return null;
    if (r.length < 5) {
      _msg('Escribe el motivo (mínimo 5 caracteres).');
      return null;
    }
    return r;
  }

  Future<void> _cambiar(String estado, {String? tituloMotivo}) async {
    String? obs;
    if (tituloMotivo != null) {
      obs = await _pedirMotivo(tituloMotivo);
      if (obs == null) return;
    }
    setState(() => _trabajando = true);
    try {
      await _db.rpc('cambiar_estado_solicitud', params: {
        'p_id': widget.solicitudId,
        'p_estado': estado,
        'p_observacion': obs,
      });
      await _cargar();
    } on PostgrestException catch (e) {
      _msg(e.message);
    } catch (_) {
      _msg('No se pudo actualizar la solicitud.');
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  Future<void> _emitirJustificante() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Emitir justificante'),
        content: const Text(
            'Confirma que revisaste el comprobante del alumno. Se generará el '
            'justificante con folio y el alumno podrá descargarlo.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Emitir')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _trabajando = true);
    try {
      final res = await _db.rpc('preparar_justificante',
          params: {'p_solicitud': widget.solicitudId}) as List;
      final d = Map<String, dynamic>.from(res.first as Map);

      final bytes = await generarJustificantePdf(
        folio: d['folio'] as String,
        alumno: (d['alumno'] ?? '').toString(),
        matricula: (d['matricula'] ?? '').toString(),
        carrera: (d['carrera'] ?? '').toString(),
        desde: DateTime.parse(d['fecha_desde'] as String),
        hasta: DateTime.parse(d['fecha_hasta'] as String),
        motivo: (d['motivo'] ?? '').toString(),
        coordinador: (d['coordinador'] ?? '').toString(),
      );

      final ruta = '${d['alumno_id']}/justificantes/${d['folio']}.pdf';
      await _db.storage.from('documentos').uploadBinary(
            ruta,
            bytes,
            fileOptions: const FileOptions(contentType: 'application/pdf'),
          );
      await _db.rpc('emitir_justificante', params: {
        'p_solicitud': widget.solicitudId,
        'p_folio': d['folio'],
        'p_ruta': ruta,
      });
      _msg('Justificante emitido: ${d['folio']}');
      await _cargar();
    } on PostgrestException catch (e) {
      _msg(e.message);
    } on StorageException catch (e) {
      _msg('No se pudo guardar el justificante: ${e.message}');
    } catch (e) {
      _msg('No se pudo emitir el justificante ($e).');
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  Widget _fila(String requisito, bool obligatorio) {
    final doc = _docs[requisito];
    final subido = doc != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(subido ? Icons.check_circle : Icons.radio_button_unchecked,
            color: subido ? const Color(0xFF2E7D32) : Colors.blueGrey),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(requisito,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(subido
                  ? '${doc['nombre_archivo']}'
                  : (obligatorio ? 'No entregado' : 'Opcional, no entregado')),
            ],
          ),
        ),
        if (subido)
          OutlinedButton(onPressed: () => _ver(doc), child: const Text('Ver')),
      ]),
    );
  }

  Widget _titulo(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      );

  String _fechaDia(String iso) {
    final d = DateTime.parse(iso);
    return '${fechaLarga(d)} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final alumno = (_sol['profiles'] ?? {}) as Map;
    final tr = _sol['tramites'] as Map<String, dynamic>;
    final obligatorios = ((tr['documentos'] as List?) ?? []).cast<String>();
    final opcionales =
        ((tr['documentos_opcionales'] as List?) ?? []).cast<String>();
    final emiteDoc = tr['emite_documento'] == true;
    final estado = _sol['estado'] as String;
    final color = estadoColor(estado);
    final f = DateTime.parse(_sol['created_at']).toLocal();
    final puede = !_trabajando;
    final revisable = estado == 'recibido' || estado == 'en_revision';

    return Scaffold(
      appBar: AppBar(title: const Text('Revisar solicitud')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(tr['nombre'],
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 20)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(estadoLabel(estado),
                              style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12)),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      Text('Alumno: ${alumno['nombre'] ?? '-'}'),
                      Text('Matrícula: ${alumno['matricula'] ?? '-'}'),
                      Text('Enviada: ${fechaLarga(f)} · ${hora(f)}'),
                      Text(tr['modalidad'] == 'presencial'
                          ? 'Modalidad: presencial'
                          : 'Modalidad: en línea'),
                      if (_sol['fecha_desde'] != null &&
                          _sol['fecha_hasta'] != null)
                        Text(
                            'Inasistencia: del ${_fechaDia(_sol['fecha_desde'])} '
                            'al ${_fechaDia(_sol['fecha_hasta'])}'),
                      const SizedBox(height: 12),
                      const Text('Motivo del alumno',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      Text(_sol['motivo'] ?? ''),
                      if (estado == 'requiere_correccion' &&
                          (_sol['observacion'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child:
                              Text('Corrección pedida: ${_sol['observacion']}'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _titulo('Documentos'),
                      for (final r in obligatorios) _fila(r, true),
                      for (final r in opcionales) _fila(r, false),
                    ],
                  ),
                ),
                JustificanteTarjeta(
                    key: ValueKey(estado), solicitudId: widget.solicitudId),
                const SizedBox(height: 16),
                GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _titulo('Historial'),
                      if (_hist.isEmpty)
                        const Text('Sin movimientos registrados.'),
                      for (final h in _hist)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${estadoLabel(h['estado'])} · '
                                '${fechaLarga(DateTime.parse(h['created_at']).toLocal())} '
                                '${hora(DateTime.parse(h['created_at']).toLocal())}',
                                style:
                                    const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              if ((h['observacion'] ?? '').toString().isNotEmpty)
                                Text('${h['observacion']}',
                                    style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _titulo('Acciones'),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        if (estado == 'recibido')
                          ElevatedButton(
                            onPressed:
                                puede ? () => _cambiar('en_revision') : null,
                            child: const Text('Iniciar revisión'),
                          ),
                        if (revisable && emiteDoc)
                          ElevatedButton(
                            onPressed: puede ? _emitirJustificante : null,
                            child: const Text('Emitir justificante'),
                          ),
                        if (revisable && !emiteDoc)
                          ElevatedButton(
                            onPressed: puede ? () => _cambiar('aprobado') : null,
                            child: const Text('Aprobar'),
                          ),
                        if (revisable)
                          OutlinedButton(
                            onPressed: puede
                                ? () => _cambiar('requiere_correccion',
                                    tituloMotivo: 'Solicitar corrección')
                                : null,
                            child: const Text('Solicitar corrección'),
                          ),
                        if (revisable || estado == 'requiere_correccion')
                          OutlinedButton(
                            onPressed: puede
                                ? () => _cambiar('rechazado',
                                    tituloMotivo: 'Rechazar solicitud')
                                : null,
                            child: const Text('Rechazar'),
                          ),
                        if (estado == 'aprobado' && !emiteDoc)
                          ElevatedButton(
                            onPressed: puede
                                ? () => _cambiar('listo_para_recoger')
                                : null,
                            child: const Text('Marcar listo para recoger'),
                          ),
                      ]),
                      if (estado == 'listo_para_recoger' ||
                          estado == 'rechazado' ||
                          estado == 'cancelado')
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                              'Esta solicitud ya no tiene acciones pendientes.'),
                        ),
                      if (estado == 'requiere_correccion')
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                              'Esperando que el alumno corrija sus documentos.'),
                        ),
                    ],
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