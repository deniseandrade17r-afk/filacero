import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../utils/avisos.dart';
import '../utils/fechas.dart';
import '../widgets/glass_card.dart';

class NotificacionesPage extends StatefulWidget {
  const NotificacionesPage({super.key});
  @override
  State<NotificacionesPage> createState() => _NotificacionesPageState();
}

class _NotificacionesPageState extends State<NotificacionesPage> {
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>> _items = [];
  bool _cargando = true;
  bool _error = false;
  String _tipo = 'todas';
  bool _soloSinLeer = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _cargar();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _cargar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final res = await _db
          .from('notificaciones')
          .select()
          .order('created_at', ascending: false)
          .limit(100);
      if (!mounted) return;
      setState(() {
        _items = [...res];
        _cargando = false;
        _error = false;
      });
      actualizarNoLeidas();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = true;
      });
    }
  }

  Future<void> _leer(Map<String, dynamic> n) async {
    if (n['leida'] == true) return;
    setState(() => n['leida'] = true);
    try {
      await _db.rpc('marcar_leida', params: {'p_id': n['id']});
    } catch (_) {}
    actualizarNoLeidas();
  }

  Future<void> _leerTodas() async {
    try {
      await _db.rpc('marcar_todas_leidas');
    } catch (_) {}
    await _cargar();
  }

  IconData _icono(String tipo) {
    switch (tipo) {
      case 'cita':
        return Icons.event_rounded;
      case 'turno':
        return Icons.confirmation_number_rounded;
      case 'estado':
        return Icons.assignment_turned_in_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Widget _tarjeta(Map<String, dynamic> n) {
    final leida = n['leida'] == true;
    final d = DateTime.parse(n['created_at']).toLocal();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: () => _leer(n),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.yellow.withValues(alpha: leida ? 0.12 : 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icono(n['tipo']), color: AppColors.navy),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n['titulo'],
                      style: TextStyle(
                          fontWeight: leida ? FontWeight.w600 : FontWeight.w800,
                          fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(n['mensaje']),
                  const SizedBox(height: 4),
                  Text('${fechaLarga(d)} · ${hora(d)}',
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            if (!leida)
              Container(
                margin: const EdgeInsets.only(left: 8, top: 4),
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    color: AppColors.red, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final vista = _items
        .where((n) =>
            (_tipo == 'todas' || n['tipo'] == _tipo) &&
            (!_soloSinLeer || n['leida'] != true))
        .toList();

    const filtros = {
      'todas': 'Todas',
      'cita': 'Citas',
      'turno': 'Turnos',
      'estado': 'Trámites',
    };

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(children: [
          Expanded(
            child: Text('Avisos',
                style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          ),
          TextButton(
              onPressed: _leerTodas, child: const Text('Marcar todo como leído')),
          IconButton(
              tooltip: 'Actualizar',
              icon: const Icon(Icons.refresh),
              onPressed: _cargar),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in filtros.entries)
            ChoiceChip(
              label: Text(e.value),
              selected: _tipo == e.key,
              onSelected: (_) => setState(() => _tipo = e.key),
            ),
          FilterChip(
            label: const Text('Sin leer'),
            selected: _soloSinLeer,
            onSelected: (v) => setState(() => _soloSinLeer = v),
          ),
        ]),
        const SizedBox(height: 16),
        if (_cargando)
          const Center(child: CircularProgressIndicator())
        else if (_error)
          const GlassCard(child: Text('No se pudieron cargar tus avisos.'))
        else if (vista.isEmpty)
          const GlassCard(child: Text('No tienes avisos.'))
        else
          for (final n in vista) _tarjeta(n),
      ],
    );
  }
}