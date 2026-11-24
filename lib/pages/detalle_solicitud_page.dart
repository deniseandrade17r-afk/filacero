import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../utils/estados.dart';
import '../utils/fechas.dart';
import '../widgets/glass_card.dart';
import 'documentos_page.dart';
import '../widgets/justificante_tarjeta.dart';

enum _Fase { hecho, actual, pendiente }

class _Paso {
  _Paso(this.titulo, this.fase, this.color, {this.fecha, this.detalle});
  final String titulo;
  final _Fase fase;
  final Color color;
  final DateTime? fecha;
  final String? detalle;
}

class DetalleSolicitudPage extends StatefulWidget {
  const DetalleSolicitudPage({super.key, required this.solicitudId});
  final dynamic solicitudId;
  @override
  State<DetalleSolicitudPage> createState() => _DetalleSolicitudPageState();
}

class _DetalleSolicitudPageState extends State<DetalleSolicitudPage> {
  final _db = Supabase.instance.client;
  Map<String, dynamic> _sol = {};
  List<Map<String, dynamic>> _hist = [];
  Map<String, dynamic>? _cita;
  bool _cargando = true;
  bool _error = false;
  bool _trabajando = false;

  static const _principal = [
    'recibido',
    'en_revision',
    'aprobado',
    'listo_para_recoger',
  ];
  static const _finales = ['rechazado', 'cancelado', 'listo_para_recoger'];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _msg(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _cargar() async {
    try {
      final sol = await _db
          .from('solicitudes')
          .select(
            'id, estado, motivo, observacion, created_at, tramites(nombre, modalidad, pasos)',
          )
          .eq('id', widget.solicitudId)
          .single();
      final hist = await _db
          .from('historial_solicitud')
          .select('estado, observacion, created_at')
          .eq('solicitud_id', widget.solicitudId)
          .order('created_at');
      final citas = await _db
          .from('citas')
          .select('estado, franjas(inicio)')
          .eq('solicitud_id', widget.solicitudId)
          .inFilter('estado', ['programada', 'llamada'])
          .limit(1);
      if (!mounted) return;
      setState(() {
        _sol = sol;
        _hist = [...hist];
        _cita = citas.isEmpty ? null : Map<String, dynamic>.from(citas.first);
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

  List<_Paso> _construirPasos() {
    final estado = _sol['estado'] as String;
    final hist = _hist.where((h) => h['estado'] != 'borrador').toList();
    if (hist.isEmpty) {
      // Solicitudes anteriores al historial o aún en borrador
      hist.add({
        'estado': estado,
        'observacion': null,
        'created_at': _sol['created_at'],
      });
    }

    final pasos = <_Paso>[];
    for (var i = 0; i < hist.length; i++) {
      final h = hist[i];
      final actual = i == hist.length - 1;
      final obs = (h['observacion'] ?? '').toString();
      pasos.add(
        _Paso(
          estadoLabel(h['estado']),
          actual ? _Fase.actual : _Fase.hecho,
          estadoColor(h['estado']),
          fecha: DateTime.parse(h['created_at']).toLocal(),
          detalle: obs.isEmpty ? null : obs,
        ),
      );
    }

    if (!_finales.contains(estado)) {
      final base = estado == 'requiere_correccion' ? 'en_revision' : estado;
      final idx = _principal.indexOf(base);
      for (var j = idx + 1; j < _principal.length; j++) {
        pasos.add(
          _Paso(estadoLabel(_principal[j]), _Fase.pendiente, Colors.blueGrey),
        );
      }
    }
    return pasos;
  }

  Future<void> _cancelar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancelar trámite'),
        content: const Text(
          'Se cancelará tu solicitud y, si tienes una cita, también se '
          'cancelará. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _trabajando = true);
    try {
      await _db.rpc('cancelar_solicitud', params: {'p_id': widget.solicitudId});
      _msg('Trámite cancelado.');
      await _cargar();
    } on PostgrestException catch (e) {
      _msg(e.message);
    } catch (_) {
      _msg('No se pudo cancelar el trámite.');
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  Widget _fila(_Paso p, bool ultimo) {
    final pendiente = p.fase == _Fase.pendiente;
    final hecho = p.fase == _Fase.hecho;
    final verde = const Color(0xFF2E7D32);
    final colorPunto = pendiente
        ? Colors.blueGrey.shade200
        : (hecho ? verde : p.color);
    final colorLinea = (pendiente || p.fase == _Fase.actual)
        ? Colors.blueGrey.shade100
        : verde;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: pendiente ? Colors.transparent : colorPunto,
                    border: Border.all(color: colorPunto, width: 2),
                  ),
                  child: hecho
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : (p.fase == _Fase.actual
                            ? const Icon(
                                Icons.circle,
                                size: 8,
                                color: Colors.white,
                              )
                            : null),
                ),
                if (!ultimo)
                  Expanded(child: Container(width: 2, color: colorLinea)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: ultimo ? 0 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.titulo,
                    style: TextStyle(
                      fontWeight: pendiente ? FontWeight.w500 : FontWeight.w800,
                      fontSize: 15,
                      color: pendiente ? Colors.blueGrey : AppColors.ink,
                    ),
                  ),
                  if (p.fecha != null)
                    Text(
                      '${fechaLarga(p.fecha!)} · ${hora(p.fecha!)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  if (p.detalle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(p.detalle!),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _pasosUniversidad(List<String> pasos) {
    final out = <Widget>[];
    var n = 0;
    for (final p in pasos) {
      if (p.startsWith('## ')) {
        n = 0;
        out.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              p.substring(3),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
          ),
        );
      } else {
        n++;
        out.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 26,
                  child: Text(
                    '$n.',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(child: Text(p)),
              ],
            ),
          ),
        );
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error) {
      return Scaffold(
        appBar: AppBar(title: const Text('Seguimiento')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No se pudo cargar la solicitud.'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _cargando = true;
                    _error = false;
                  });
                  _cargar();
                },
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final tr = _sol['tramites'] as Map<String, dynamic>;
    final estado = _sol['estado'] as String;
    final color = estadoColor(estado);
    final pasosU = ((tr['pasos'] as List?) ?? []).cast<String>();
    final pasos = _construirPasos();
    final presencial = tr['modalidad'] == 'presencial';
    final puedeCancelar = [
      'recibido',
      'en_revision',
      'requiere_correccion',
    ].contains(estado);
    final puedeDocumentos =
        estado == 'borrador' || estado == 'requiere_correccion';

    return Scaffold(
      appBar: AppBar(
        title: Text(tr['nombre']),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _cargar,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Estado de tu trámite',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              estadoLabel(estado),
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Motivo: ${_sol['motivo'] ?? ''}'),
                      const SizedBox(height: 20),
                      for (var i = 0; i < pasos.length; i++)
                        _fila(pasos[i], i == pasos.length - 1),
                    ],
                  ),
                ),
                if (_cita != null) ...[
                  const SizedBox(height: 16),
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        const Icon(Icons.event_rounded, color: AppColors.navy),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Builder(
                            builder: (_) {
                              final ini = DateTime.parse(
                                _cita!['franjas']['inicio'],
                              ).toLocal();
                              return Text(
                                'Tu cita: ${fechaLarga(ini)} · ${hora(ini)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (presencial && estado == 'recibido') ...[
                  const SizedBox(height: 16),
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.navy),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Aún no tienes cita. Agéndala en la pestaña Citas.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                JustificanteTarjeta(
                  key: ValueKey(estado),
                  solicitudId: widget.solicitudId,
                ),
                if (pasosU.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        title: const Text(
                          'Pasos del trámite en la universidad',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          12,
                          0,
                          12,
                          12,
                        ),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        children: _pasosUniversidad(pasosU),
                      ),
                    ),
                  ),
                ],
                if (puedeDocumentos || puedeCancelar) ...[
                  const SizedBox(height: 16),
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (puedeDocumentos)
                          ElevatedButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DocumentosPage(
                                  solicitudId: widget.solicitudId,
                                ),
                              ),
                            ).then((_) => _cargar()),
                            child: const Text('Documentos'),
                          ),
                        if (puedeCancelar)
                          OutlinedButton(
                            onPressed: _trabajando ? null : _cancelar,
                            child: const Text(
                              'Cancelar trámite',
                              style: TextStyle(color: AppColors.red),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
