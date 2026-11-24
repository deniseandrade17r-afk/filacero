import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../utils/fechas.dart';
import '../widgets/glass_card.dart';

class DemandaPage extends StatefulWidget {
  const DemandaPage({super.key});
  @override
  State<DemandaPage> createState() => _DemandaPageState();
}

class _DemandaPageState extends State<DemandaPage> {
  final _db = Supabase.instance.client;
  Map<String, dynamic>? _d;
  bool _cargando = true;
  bool _error = false;
  int _dias = 90;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final res = await _db.rpc('panel_demanda', params: {'p_dias': _dias});
      if (!mounted) return;
      setState(() {
        _d = Map<String, dynamic>.from(res as Map);
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

  void _periodo(int dias) {
    setState(() {
      _dias = dias;
      _cargando = true;
    });
    _cargar();
  }

  List<Map<String, dynamic>> _lista(String k) => ((_d?[k] as List?) ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  int _n(dynamic v) => (v as num?)?.toInt() ?? 0;

  String _semana(String iso) => fechaLarga(DateTime.parse(iso));

  Widget _titulo(String t, {String? sub}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            if (sub != null)
              Text(sub, style: const TextStyle(fontSize: 12)),
          ],
        ),
      );

  Widget _kpi(double ancho, String valor, String etiqueta, IconData icono) =>
      SizedBox(
        width: ancho,
        child: GlassCard(
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

  Widget _barraH(String etiqueta, int valor, int max) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(etiqueta)),
              Text('$valor',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: max == 0 ? 0 : valor / max,
                minHeight: 10,
                color: AppColors.navy,
                backgroundColor: AppColors.navy.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      );

  Widget _porTramite() {
    final lista = _lista('por_tramite');
    if (lista.isEmpty) {
      return const Text('Aún no hay solicitudes en este periodo.');
    }
    final max = lista.map((e) => _n(e['total'])).reduce((a, b) => a > b ? a : b);
    return Column(children: [
      for (final e in lista) _barraH(e['nombre'], _n(e['total']), max),
    ]);
  }

  Widget _porSemana() {
    final lista = _lista('por_semana');
    if (lista.isEmpty) return const Text('Sin datos.');
    final totales = lista.map((e) => _n(e['total'])).toList();
    final max = totales.reduce((a, b) => a > b ? a : b);
    final prom = totales.fold<int>(0, (a, b) => a + b) / totales.length;
    const alto = 150.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: alto + 50,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final e in lista)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Builder(builder: (_) {
                      final v = _n(e['total']);
                      final pico = v >= 3 && v > prom * 1.5;
                      final d = DateTime.parse(e['semana']);
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('$v', style: const TextStyle(fontSize: 10)),
                          const SizedBox(height: 2),
                          Container(
                            height: max == 0 ? 2 : (v / max * alto).clamp(2, alto),
                            decoration: BoxDecoration(
                              color: pico ? AppColors.red : AppColors.navy,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('${d.day}/${d.month}',
                              style: const TextStyle(fontSize: 9)),
                        ],
                      );
                    }),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Container(width: 10, height: 10, color: AppColors.navy),
          const SizedBox(width: 6),
          const Text('Semana normal', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 16),
          Container(width: 10, height: 10, color: AppColors.red),
          const SizedBox(width: 6),
          const Text('Semana pico', style: TextStyle(fontSize: 12)),
        ]),
        const SizedBox(height: 4),
        const Text('Fecha: lunes de cada semana.', style: TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _proximas() {
    final lista = _lista('proximas');
    if (lista.isEmpty) return const Text('Sin datos.');
    return Column(children: [
      for (final e in lista)
        Builder(builder: (_) {
          final citas = _n(e['citas']);
          final cap = _n(e['capacidad']);
          final pct = cap == 0 ? 0.0 : citas / cap;
          final alta = pct >= 0.8;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text('Semana del ${_semana(e['semana'])}')),
                  if (alta)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Text('Alta ocupación',
                          style: TextStyle(
                              color: AppColors.red,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ),
                  Text(cap == 0 ? 'Sin horarios' : '$citas de $cap',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: pct.clamp(0, 1).toDouble(),
                    minHeight: 10,
                    color: alta ? AppColors.red : AppColors.yellow,
                    backgroundColor: AppColors.navy.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          );
        }),
    ]);
  }

  Widget _picos() {
    final lista = _lista('por_semana')
        .where((e) => _n(e['total']) > 0)
        .toList()
      ..sort((a, b) => _n(b['total']).compareTo(_n(a['total'])));
    if (lista.isEmpty) return const Text('Todavía no hay historial suficiente.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in lista.take(3))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              const Icon(Icons.trending_up, size: 18, color: AppColors.red),
              const SizedBox(width: 8),
              Expanded(child: Text('Semana del ${_semana(e['semana'])}')),
              Text('${_n(e['total'])} solicitudes',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final d = _d;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(children: [
          Expanded(
            child: Text('Panel de demanda',
                style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          ),
          IconButton(
              tooltip: 'Actualizar',
              icon: const Icon(Icons.refresh),
              onPressed: _cargar),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in const [30, 90, 180])
            ChoiceChip(
              label: Text('Últimos $p días'),
              selected: _dias == p,
              onSelected: (_) => _periodo(p),
            ),
        ]),
        const SizedBox(height: 16),
        if (_cargando)
          const Center(child: CircularProgressIndicator())
        else if (_error || d == null)
          const GlassCard(child: Text('No se pudo cargar el panel.'))
        else ...[
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 900 ? 4 : 2;
            final w = (c.maxWidth - 12 * (cols - 1)) / cols;
            final prom = d['dias_promedio'];
            return Wrap(spacing: 12, runSpacing: 12, children: [
              _kpi(w, '${_n(d['total'])}', 'Solicitudes en el periodo',
                  Icons.assignment_rounded),
              _kpi(w, '${_n(d['pendientes'])}', 'Por revisar',
                  Icons.inbox_rounded),
              _kpi(w, '${_n(d['citas_hoy'])}', 'Citas de hoy',
                  Icons.event_rounded),
              _kpi(w, prom == null ? '-' : '$prom días',
                  'Resolución promedio', Icons.timer_outlined),
            ]);
          }),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _titulo('Trámites más solicitados',
                    sub: 'Últimos $_dias días'),
                _porTramite(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _titulo('Solicitudes por semana',
                    sub: 'Últimas 12 semanas; en rojo, las semanas pico'),
                _porSemana(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _titulo('Próximas 4 semanas',
                    sub: 'Citas agendadas frente a los lugares disponibles'),
                _proximas(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _titulo('Semanas pico del historial'),
                _picos(),
              ],
            ),
          ),
        ],
      ],
    );
  }
}