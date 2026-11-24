import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/estados.dart';
import '../utils/fechas.dart';
import '../widgets/glass_card.dart';
import 'revisar_solicitud_page.dart';

class SolicitudesPage extends StatefulWidget {
  const SolicitudesPage({super.key});
  @override
  State<SolicitudesPage> createState() => _SolicitudesPageState();
}

class _SolicitudesPageState extends State<SolicitudesPage> {
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>> _items = [];
  bool _cargando = true;
  bool _error = false;
  String _filtro = 'pendientes';
  Timer? _timer;

  static const _filtros = {
    'pendientes': 'Por revisar',
    'correccion': 'En corrección',
    'aprobadas': 'Aprobadas',
    'todas': 'Todas',
  };

  static const _estadosDe = {
    'pendientes': ['recibido', 'en_revision'],
    'correccion': ['requiere_correccion'],
    'aprobadas': ['aprobado', 'listo_para_recoger'],
  };

  @override
  void initState() {
    super.initState();
    _cargar();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _cargar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final res = await _db
          .from('solicitudes')
          .select(
              'id, estado, motivo, created_at, profiles(nombre, matricula), tramites(nombre)')
          .neq('estado', 'borrador')
          .order('created_at', ascending: false)
          .limit(200);
      if (!mounted) return;
      setState(() {
        _items = [...res];
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

  List<Map<String, dynamic>> get _vista {
    final estados = _estadosDe[_filtro];
    final lista = _items
        .where((s) => estados == null || estados.contains(s['estado']))
        .toList();
    if (_filtro == 'pendientes') {
      // Las más antiguas primero
      lista.sort((a, b) =>
          (a['created_at'] as String).compareTo(b['created_at'] as String));
    }
    return lista;
  }

  Widget _tarjeta(Map<String, dynamic> s) {
    final alumno = (s['profiles'] ?? {}) as Map;
    final d = DateTime.parse(s['created_at']).toLocal();
    final color = estadoColor(s['estado']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => RevisarSolicitudPage(solicitudId: s['id'])),
        ).then((_) => _cargar()),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alumno['nombre'] ?? 'Alumno',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 2),
                Text('Matrícula ${alumno['matricula'] ?? '-'} · '
                    '${s['tramites']['nombre']}'),
                const SizedBox(height: 2),
                Text('Enviada ${fechaLarga(d)} · ${hora(d)}',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(estadoLabel(s['estado']),
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
          const Icon(Icons.chevron_right),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final vista = _vista;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(children: [
          Expanded(
            child: Text('Solicitudes',
                style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          ),
          IconButton(
              tooltip: 'Actualizar',
              icon: const Icon(Icons.refresh),
              onPressed: _cargar),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in _filtros.entries)
            ChoiceChip(
              label: Text(e.value),
              selected: _filtro == e.key,
              onSelected: (_) => setState(() => _filtro = e.key),
            ),
        ]),
        const SizedBox(height: 16),
        if (_cargando)
          const Center(child: CircularProgressIndicator())
        else if (_error)
          const GlassCard(child: Text('No se pudieron cargar las solicitudes.'))
        else if (vista.isEmpty)
          const GlassCard(child: Text('No hay solicitudes en esta vista.'))
        else
          for (final s in vista) _tarjeta(s),
      ],
    );
  }
}