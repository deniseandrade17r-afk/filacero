import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../utils/avisos.dart';
import '../utils/estados.dart';
import '../utils/fechas.dart';
import '../utils/navegacion.dart';
import '../widgets/asistente_tarjeta.dart';
import '../widgets/glass_card.dart';
import '../widgets/turno_card.dart';
import 'detalle_solicitud_page.dart';
import 'documentos_page.dart';

class _Pendiente {
  _Pendiente(this.icono, this.texto, this.boton, this.accion);
  final IconData icono;
  final String texto;
  final String boton;
  final VoidCallback accion;
}

class InicioAlumnoPage extends StatefulWidget {
  const InicioAlumnoPage({super.key});
  @override
  State<InicioAlumnoPage> createState() => _InicioAlumnoPageState();
}

class _InicioAlumnoPageState extends State<InicioAlumnoPage> {
  final _db = Supabase.instance.client;
  String _nombre = '';
  List<Map<String, dynamic>> _sols = [];
  List<Map<String, dynamic>> _citas = [];
  List<Map<String, dynamic>> _espera = [];
  bool _cargando = true;
  bool _error = false;
  Timer? _timer;

  static const _activas = [
    'recibido',
    'en_revision',
    'requiere_correccion',
    'aprobado'
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _cargar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final uid = _db.auth.currentUser!.id;
      final perfil =
          await _db.from('profiles').select('nombre').eq('id', uid).single();
      final sols = await _db
          .from('solicitudes')
          .select('id, estado, created_at, tramites(nombre, modalidad)')
          .eq('alumno_id', uid)
          .order('created_at', ascending: false);
      final citas = await _db
          .from('citas')
          .select(
              'solicitud_id, estado, franjas(inicio), solicitudes(tramites(nombre))')
          .eq('alumno_id', uid)
          .inFilter('estado', ['programada', 'llamada']);
      final espera = await _db
          .from('lista_espera')
          .select('solicitud_id')
          .eq('alumno_id', uid)
          .eq('estado', 'activa');
      if (!mounted) return;
      setState(() {
        _nombre = '${perfil['nombre'] ?? ''}';
        _sols = [...sols];
        _citas = [...citas];
        _espera = [...espera];
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

  void _abrirDocs(dynamic id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DocumentosPage(solicitudId: id)),
    ).then((_) => _cargar());
  }

  void _abrirDetalle(dynamic id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetalleSolicitudPage(solicitudId: id)),
    ).then((_) => _cargar());
  }

  List<_Pendiente> _pendientes() {
    final conCita = {
      ..._citas.map((c) => c['solicitud_id']),
      ..._espera.map((e) => e['solicitud_id']),
    };
    final out = <_Pendiente>[];
    for (final s in _sols) {
      final nombre = s['tramites']['nombre'];
      switch (s['estado']) {
        case 'borrador':
          out.add(_Pendiente(Icons.upload_file_rounded,
              'Completa los documentos de $nombre', 'Subir', () => _abrirDocs(s['id'])));
          break;
        case 'requiere_correccion':
          out.add(_Pendiente(Icons.edit_document,
              'Corrige los documentos de $nombre', 'Corregir', () => _abrirDocs(s['id'])));
          break;
        case 'recibido':
          if (s['tramites']['modalidad'] == 'presencial' &&
              !conCita.contains(s['id'])) {
            out.add(_Pendiente(Icons.event_rounded,
                'Agenda tu cita para $nombre', 'Agendar', () => irA('Citas')));
          }
          break;
      }
    }
    return out;
  }

  Map<String, dynamic>? get _proxima {
    if (_citas.isEmpty) return null;
    final l = [..._citas]..sort((a, b) => (a['franjas']['inicio'] as String)
        .compareTo(b['franjas']['inicio'] as String));
    return l.first;
  }

  Widget _titulo(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Text(t,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
      );

  Widget _kpi(double ancho, String valor, String etiqueta, IconData icono,
          VoidCallback onTap) =>
      SizedBox(
        width: ancho,
        child: GlassCard(
          onTap: onTap,
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.yellow.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icono, color: AppColors.navy),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(valor,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          color: AppColors.navy)),
                  Text(etiqueta, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pendientes = _pendientes();
    final activas = _sols.where((s) => _activas.contains(s['estado'])).length;
    final proxima = _proxima;
    final recientes = _sols.take(3).toList();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(children: [
          Expanded(
            child: Text(_nombre.isEmpty ? '¡Hola!' : '¡Hola, $_nombre!',
                style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          ),
          IconButton(
              tooltip: 'Actualizar',
              icon: const Icon(Icons.refresh),
              onPressed: _cargar),
        ]),
        const SizedBox(height: 16),
        const TurnoCard(),
        const AsistenteTarjeta(),
        if (_cargando)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator()))
        else if (_error)
          const GlassCard(child: Text('No se pudo cargar tu resumen.'))
        else ...[
          LayoutBuilder(builder: (context, c) {
            final w = (c.maxWidth - 12) / 2;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              _kpi(w, '$activas', 'Solicitudes activas',
                  Icons.assignment_rounded, () => irA('Seguimiento')),
              ValueListenableBuilder<int>(
                valueListenable: noLeidas,
                builder: (_, n, __) => _kpi(w, '$n', 'Avisos sin leer',
                    Icons.notifications_rounded, () => irA('Avisos')),
              ),
            ]);
          }),
          const SizedBox(height: 12),
          GlassCard(
            onTap: () => irA('Citas'),
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const Icon(Icons.event_rounded, color: AppColors.navy),
              const SizedBox(width: 12),
              Expanded(
                child: Builder(builder: (_) {
                  if (proxima == null) {
                    return const Text('No tienes citas programadas.');
                  }
                  final ini =
                      DateTime.parse(proxima['franjas']['inicio']).toLocal();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tu próxima cita',
                          style: TextStyle(fontSize: 12)),
                      Text(proxima['solicitudes']['tramites']['nombre'],
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${fechaLarga(ini)} · ${hora(ini)}'),
                    ],
                  );
                }),
              ),
              const Icon(Icons.chevron_right),
            ]),
          ),
          const SizedBox(height: 16),
          _titulo(context, 'Pendiente de ti'),
          if (pendientes.isEmpty)
            const GlassCard(
              padding: EdgeInsets.all(16),
              child: Row(children: [
                Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
                SizedBox(width: 12),
                Expanded(child: Text('Todo al día. No tienes nada pendiente.')),
              ]),
            )
          else
            for (final p in pendientes)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Icon(p.icono, color: AppColors.red),
                    const SizedBox(width: 12),
                    Expanded(child: Text(p.texto)),
                    const SizedBox(width: 8),
                    OutlinedButton(onPressed: p.accion, child: Text(p.boton)),
                  ]),
                ),
              ),
          const SizedBox(height: 8),
          _titulo(context, 'Mis solicitudes recientes'),
          if (recientes.isEmpty)
            const GlassCard(
              padding: EdgeInsets.all(16),
              child: Text('Aún no tienes solicitudes. Empieza en la pestaña Trámites.'),
            )
          else
            for (final s in recientes)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  onTap: () => _abrirDetalle(s['id']),
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Expanded(
                      child: Text(s['tramites']['nombre'],
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: estadoColor(s['estado']).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(estadoLabel(s['estado']),
                          style: TextStyle(
                              color: estadoColor(s['estado']),
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ),
                    const Icon(Icons.chevron_right),
                  ]),
                ),
              ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ElevatedButton.icon(
              onPressed: () => irA('Trámites'),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo trámite'),
            ),
            OutlinedButton(
              onPressed: () => irA('Seguimiento'),
              child: const Text('Ver todas mis solicitudes'),
            ),
          ]),
        ],
      ],
    );
  }
}