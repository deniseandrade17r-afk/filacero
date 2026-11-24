import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/fechas.dart';
import '../widgets/glass_card.dart';

class AgendarCitaPage extends StatefulWidget {
  const AgendarCitaPage(
      {super.key, required this.solicitudId, required this.tramite});
  final dynamic solicitudId;
  final String tramite;
  @override
  State<AgendarCitaPage> createState() => _AgendarCitaPageState();
}

class _AgendarCitaPageState extends State<AgendarCitaPage> {
  final _db = Supabase.instance.client;
  final _motivo = TextEditingController();
  late final List<DateTime> _dias = _generarDias();
  DateTime? _dia;
  List<Map<String, dynamic>> _franjas = [];
  dynamic _franjaId;
  bool _cargando = false;
  bool _urgente = false;
  bool _enviando = false;

  List<DateTime> _generarDias() {
    final hoy = DateTime.now();
    final out = <DateTime>[];
    for (var i = 0; out.length < 10; i++) {
      final d = DateTime(hoy.year, hoy.month, hoy.day + i);
      if (d.weekday <= 5) out.add(d);
    }
    return out;
  }

  void _msg(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  String _soloFecha(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _elegirDia(DateTime d) async {
    setState(() {
      _dia = d;
      _franjaId = null;
      _cargando = true;
    });
    try {
      final res = await _db.rpc('franjas_con_cupo', params: {
        'p_desde': d.toUtc().toIso8601String(),
        'p_hasta': DateTime(d.year, d.month, d.day + 1).toUtc().toIso8601String(),
      });
      if (!mounted) return;
      setState(() {
        _franjas = List<Map<String, dynamic>>.from(res as List);
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
      _msg('No se pudieron cargar los horarios.');
    }
  }

  Future<void> _agendar() async {
    if (_franjaId == null) {
      _msg('Elige un horario.');
      return;
    }
    if (_urgente && _motivo.text.trim().length < 10) {
      _msg('Explica el motivo de la urgencia (mínimo 10 caracteres).');
      return;
    }
    setState(() => _enviando = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _db.rpc('agendar_cita', params: {
        'p_solicitud': widget.solicitudId,
        'p_franja': _franjaId,
        'p_urgente': _urgente,
        'p_motivo': _urgente ? _motivo.text.trim() : null,
      });
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(content: Text('Cita agendada.')));
    } on PostgrestException catch (e) {
      _msg(e.message);
      if (_dia != null) _elegirDia(_dia!);
    } catch (_) {
      _msg('No se pudo agendar la cita.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _esperar() async {
    setState(() => _enviando = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _db.rpc('unirse_lista_espera', params: {
        'p_solicitud': widget.solicitudId,
        'p_dia': _soloFecha(_dia!),
      });
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
          content: Text('Quedaste en la lista de espera del ${fechaLarga(_dia!)}.')));
    } on PostgrestException catch (e) {
      _msg(e.message);
    } catch (_) {
      _msg('No se pudo unir a la lista de espera.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final sinLugares = _dia != null &&
        !_cargando &&
        !_franjas.any((f) => (f['libres'] as num) > 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Agendar cita')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: GlassCard(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.tramite,
                      style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  const Text('Elige el día',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final d in _dias)
                      ChoiceChip(
                        label: Text('${diaCorto(d)} ${d.day}'),
                        selected: _dia == d,
                        onSelected: (_) => _elegirDia(d),
                      ),
                  ]),
                  if (_dia != null) ...[
                    const SizedBox(height: 20),
                    Text('Horarios del ${fechaLarga(_dia!)}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    if (_cargando)
                      const Center(child: CircularProgressIndicator())
                    else if (_franjas.isEmpty)
                      const Text('No hay horarios para este día.')
                    else
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final f in _franjas)
                          ChoiceChip(
                            label: Text(
                                '${hora(DateTime.parse(f['inicio']).toLocal())}'
                                '${(f['libres'] as num) == 0 ? ' · lleno' : ''}'),
                            selected: _franjaId == f['id'],
                            onSelected: ((f['libres'] as num) > 0 || _urgente)
                                ? (_) => setState(() => _franjaId = f['id'])
                                : null,
                          ),
                      ]),
                    if (sinLugares && !_urgente) ...[
                      const SizedBox(height: 16),
                      const Text(
                          'No quedan lugares este día. Puedes unirte a la lista de '
                          'espera: si alguien cancela, se te asigna el horario '
                          'automáticamente.'),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _enviando ? null : _esperar,
                        child: const Text('Unirme a la lista de espera de este día'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Es una urgencia',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text(
                          'Alumno foráneo, situación médica o plazo que vence hoy. '
                          'Debe justificarse y el coordinador la revisará.'),
                      value: _urgente,
                      onChanged: (v) => setState(() {
                        _urgente = v;
                        _franjaId = null;
                      }),
                    ),
                    if (_urgente)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextField(
                          controller: _motivo,
                          maxLines: 2,
                          decoration: const InputDecoration(
                              labelText: 'Motivo de la urgencia',
                              alignLabelWithHint: true),
                        ),
                      ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: (_franjaId != null && !_enviando) ? _agendar : null,
                      child: _enviando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Confirmar cita'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}