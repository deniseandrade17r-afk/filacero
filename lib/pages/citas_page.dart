import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../utils/fechas.dart';
import '../widgets/glass_card.dart';
import '../widgets/turno_card.dart';
import 'agendar_cita_page.dart';

class CitasPage extends StatefulWidget {
  const CitasPage({super.key});
  @override
  State<CitasPage> createState() => _CitasPageState();
}

class _CitasPageState extends State<CitasPage> {
  final _db = Supabase.instance.client;
  late Future<Map<String, List<Map<String, dynamic>>>> _f = _cargar();

  Future<Map<String, List<Map<String, dynamic>>>> _cargar() async {
    final uid = _db.auth.currentUser!.id;

    // Citas activas: programadas y ya llamadas
    final citasRaw = await _db
        .from('citas')
        .select(
            'id, estado, solicitud_id, urgente, franjas(inicio, fin), solicitudes(tramites(nombre))')
        .eq('alumno_id', uid)
        .inFilter('estado', ['programada', 'llamada']);
    final citas = [...citasRaw]..sort((a, b) =>
        (a['franjas']['inicio'] as String)
            .compareTo(b['franjas']['inicio'] as String));

    final solicitudes = await _db
        .from('solicitudes')
        .select('id, tramites(nombre, modalidad)')
        .eq('alumno_id', uid)
        .eq('estado', 'recibido');

    final espera = await _db
        .from('lista_espera')
        .select('id, dia, solicitud_id, solicitudes(tramites(nombre))')
        .eq('alumno_id', uid)
        .eq('estado', 'activa');

    // Solicitudes cuya cita ya fue atendida: no deben volver a aparecer como pendientes
    final atendidas = await _db
        .from('citas')
        .select('solicitud_id')
        .eq('alumno_id', uid)
        .eq('estado', 'atendida');

    final ocupadas = {
      ...citas.map((c) => c['solicitud_id']),
      ...espera.map((e) => e['solicitud_id']),
      ...atendidas.map((a) => a['solicitud_id']),
    };
    final pendientes = solicitudes
        .where((s) =>
            s['tramites']['modalidad'] == 'presencial' &&
            !ocupadas.contains(s['id']))
        .toList();

    return {'citas': citas, 'pendientes': pendientes, 'espera': [...espera]};
  }

  void _recargar() {
    setState(() {
      _f = _cargar();
    });
  }

  Future<void> _rpc(String fn, Map<String, dynamic> params, String ok) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _db.rpc(fn, params: params);
      messenger.showSnackBar(SnackBar(content: Text(ok)));
    } on PostgrestException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('No se pudo completar la acción.')));
    }
    if (mounted) _recargar();
  }

  Future<void> _cancelar(dynamic id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancelar cita'),
        content: const Text('¿Seguro que quieres cancelar esta cita?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Sí, cancelar')),
        ],
      ),
    );
    if (ok == true) await _rpc('cancelar_cita', {'p_cita': id}, 'Cita cancelada.');
  }

  Widget _tarjetaCita(Map<String, dynamic> c) {
    final ini = DateTime.parse(c['franjas']['inicio']).toLocal();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.yellow.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.event_rounded, color: AppColors.navy),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c['solicitudes']['tramites']['nombre'],
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 2),
                Text('${fechaLarga(ini)} · ${hora(ini)}'),
                if (c['urgente'] == true)
                  const Text('Cita urgente',
                      style: TextStyle(
                          color: AppColors.red, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          if (c['estado'] == 'programada')
            TextButton(
                onPressed: () => _cancelar(c['id']),
                child: const Text('Cancelar'))
          else
            const Text('Es tu turno',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.navy)),
        ]),
      ),
    );
  }

  Widget _tarjetaPendiente(Map<String, dynamic> s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s['tramites']['nombre'],
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 2),
                const Text('Documentos completos · falta agendar tu cita'),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AgendarCitaPage(
                    solicitudId: s['id'], tramite: s['tramites']['nombre']),
              ),
            ).then((_) => _recargar()),
            child: const Text('Agendar'),
          ),
        ]),
      ),
    );
  }

  Widget _tarjetaEspera(Map<String, dynamic> e) {
    final dia = DateTime.parse(e['dia']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e['solicitudes']['tramites']['nombre'],
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 2),
                Text('Esperando un lugar el ${fechaLarga(dia)}'),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _rpc('salir_lista_espera', {'p_id': e['id']},
                'Saliste de la lista de espera.'),
            child: const Text('Salir'),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(children: [
          Expanded(
            child: Text('Mis citas',
                style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          ),
          IconButton(
              tooltip: 'Actualizar',
              icon: const Icon(Icons.refresh),
              onPressed: _recargar),
        ]),
        const SizedBox(height: 12),
        const TurnoCard(),
        FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
          future: _f,
          builder: (context, snap) {
            if (snap.hasError) return const Text('No se pudieron cargar tus citas.');
            if (!snap.hasData) {
              return const Center(
                  child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator()));
            }
            final citas = snap.data!['citas']!;
            final pend = snap.data!['pendientes']!;
            final espera = snap.data!['espera']!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (citas.isEmpty)
                  const GlassCard(child: Text('No tienes citas programadas.')),
                for (final c in citas) _tarjetaCita(c),
                if (pend.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Solicitudes listas para agendar',
                      style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  for (final s in pend) _tarjetaPendiente(s),
                ],
                if (espera.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('En lista de espera',
                      style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  for (final e in espera) _tarjetaEspera(e),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}