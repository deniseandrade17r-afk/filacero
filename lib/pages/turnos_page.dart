import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../utils/fechas.dart';
import '../widgets/glass_card.dart';

class TurnosPage extends StatefulWidget {
  const TurnosPage({super.key});
  @override
  State<TurnosPage> createState() => _TurnosPageState();
}

class _TurnosPageState extends State<TurnosPage> {
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>> _fila = [];
  bool _cargando = true;
  bool _error = false;
  bool _llamando = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _cargar();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _cargar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final res = await _db.rpc('fila_hoy') as List;
      if (!mounted) return;
      setState(() {
        _fila = res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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

  void _aviso(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _llamar() async {
    setState(() => _llamando = true);
    try {
      final id = await _db.rpc('llamar_siguiente');
      _aviso(id == null ? 'No hay más turnos programados para hoy.' : 'Turno llamado.');
    } on PostgrestException catch (e) {
      _aviso(e.message);
    } catch (_) {
      _aviso('No se pudo llamar al siguiente turno.');
    } finally {
      if (mounted) setState(() => _llamando = false);
    }
    _cargar();
  }

  Future<void> _marcar(dynamic id, String estado) async {
    try {
      await _db.rpc('marcar_cita', params: {'p_cita': id, 'p_estado': estado});
    } on PostgrestException catch (e) {
      _aviso(e.message);
    } catch (_) {
      _aviso('No se pudo actualizar el turno.');
    }
    _cargar();
  }

  Widget _etiqueta(String texto, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(texto,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 12)),
      );

  Widget _tarjeta(Map<String, dynamic> f) {
    final llamado = f['estado'] == 'llamada';
    final urgente = f['urgente'] == true;
    final ini = DateTime.parse(f['inicio']).toLocal();
    final motivo = (f['motivo_urgencia'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                backgroundColor:
                    llamado ? AppColors.yellow : AppColors.navy.withValues(alpha: 0.12),
                child: Text('${f['pos']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: AppColors.navy)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f['alumno'] ?? 'Alumno',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    Text('Matrícula ${f['matricula'] ?? '-'} · ${f['tramite']}'),
                    Text('Cita de las ${hora(ini)}'),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: [
              if (llamado) _etiqueta('Llamado', const Color(0xFFB7791F)),
              if (urgente) _etiqueta('Urgente', AppColors.red),
            ]),
            if (urgente && motivo.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Motivo: $motivo'),
              ),
            if (llamado)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  ElevatedButton(
                    onPressed: () => _marcar(f['cita_id'], 'atendida'),
                    child: const Text('Atendido'),
                  ),
                  OutlinedButton(
                    onPressed: () => _marcar(f['cita_id'], 'no_se_presento'),
                    child: const Text('No se presentó'),
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Fila de hoy',
            style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('${_fila.length} en espera · se actualiza automáticamente'),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _llamando ? null : _llamar,
          child: const Text('Llamar siguiente'),
        ),
        const SizedBox(height: 20),
        if (_cargando)
          const Center(child: CircularProgressIndicator())
        else if (_error)
          const GlassCard(child: Text('No se pudo cargar la fila.'))
        else if (_fila.isEmpty)
          const GlassCard(child: Text('No hay citas en la fila hoy.'))
        else
          for (final f in _fila) _tarjeta(f),
      ],
    );
  }
}