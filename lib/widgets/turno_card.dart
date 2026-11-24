import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../utils/fechas.dart';
import 'glass_card.dart';

class TurnoCard extends StatefulWidget {
  const TurnoCard({super.key});
  @override
  State<TurnoCard> createState() => _TurnoCardState();
}

class _TurnoCardState extends State<TurnoCard> {
  final _db = Supabase.instance.client;
  Map<String, dynamic>? _t;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _cargar();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _cargar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final res = await _db.rpc('mi_turno') as List;
      if (!mounted) return;
      setState(() {
        _t = res.isEmpty ? null : Map<String, dynamic>.from(res.first as Map);
      });
    } catch (_) {}
  }

  Widget _dato(String valor, String etiqueta) => Expanded(
        child: Column(children: [
          Text(valor,
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.navy)),
          const SizedBox(height: 2),
          Text(etiqueta,
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final t = _t;
    if (t == null) return const SizedBox.shrink();

    final llamado = t['estado'] == 'llamada';
    final ini = DateTime.parse(t['inicio']).toLocal();
    final minutos = (t['minutos'] as num).toInt();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tu turno de hoy',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${t['tramite']} · cita de las ${hora(ini)}'),
            if (t['urgente'] == true)
              const Text('Cita urgente',
                  style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            if (llamado)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.yellow.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(children: [
                  Icon(Icons.notifications_active_rounded,
                      size: 36, color: AppColors.navy),
                  SizedBox(height: 6),
                  Text('¡Es tu turno!',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  SizedBox(height: 4),
                  Text(
                      'Pasa a la coordinación. Tienes 10 minutos antes de que el '
                      'turno pase al siguiente.',
                      textAlign: TextAlign.center),
                ]),
              )
            else
              Row(children: [
                _dato('#${t['posicion']}', 'Tu lugar en la fila'),
                _dato('${t['delante']}', 'Personas delante'),
                _dato(minutos == 0 ? 'Ya casi' : '~$minutos min', 'Espera estimada'),
              ]),
            const SizedBox(height: 12),
            const Text('Se actualiza automáticamente.',
                style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}