import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../utils/fechas.dart';
import '../widgets/glass_card.dart';

class HorariosPage extends StatefulWidget {
  const HorariosPage({super.key});
  @override
  State<HorariosPage> createState() => _HorariosPageState();
}

class _HorariosPageState extends State<HorariosPage> {
  final _db = Supabase.instance.client;
  late final List<DateTime> _dias = _generarDias();
  late DateTime _dia = _dias.first;
  List<Map<String, dynamic>> _franjas = [];
  bool _cargando = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  List<DateTime> _generarDias() {
    final hoy = DateTime.now();
    final out = <DateTime>[];
    for (var i = 0; out.length < 14; i++) {
      final d = DateTime(hoy.year, hoy.month, hoy.day + i);
      if (d.weekday <= 5) out.add(d);
    }
    return out;
  }

  String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _msg(String t) {
    if (!mounted) return;
    mostrarAviso(context, t);
  }

  Future<void> _cargar() async {
    try {
      final res = await _db.rpc('franjas_dia', params: {'p_dia': _iso(_dia)}) as List;
      if (!mounted) return;
      setState(() {
        _franjas = res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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

  void _elegirDia(DateTime d) {
    setState(() {
      _dia = d;
      _cargando = true;
    });
    _cargar();
  }

  Future<void> _otraFecha() async {
    final hoy = DateTime.now();
    final f = await showDatePicker(
      context: context,
      initialDate: _dia,
      firstDate: hoy.subtract(const Duration(days: 30)),
      lastDate: hoy.add(const Duration(days: 180)),
    );
    if (f != null) _elegirDia(DateTime(f.year, f.month, f.day));
  }

  Future<void> _actualizar(
      Map<String, dynamic> f, Map<String, dynamic> cambios) async {
    try {
      await _db.from('franjas').update(cambios).eq('id', f['id']);
    } on PostgrestException catch (e) {
      _msg(e.message);
    } catch (_) {
      _msg('No se pudo actualizar el horario.');
    }
    await _cargar();
  }

  Future<void> _cambiarCupo(Map<String, dynamic> f, int delta) async {
    final nuevo = (f['cupo'] as num).toInt() + delta;
    if (nuevo < 1) return;
    await _actualizar(f, {'cupo': nuevo});
  }

  Future<void> _cambiarDia(bool activo) async {
    try {
      final n = await _db
          .rpc('cambiar_dia', params: {'p_dia': _iso(_dia), 'p_activo': activo});
      _msg(activo
          ? 'Se activaron $n horarios.'
          : 'Se desactivaron $n horarios (los que tienen citas se conservan).');
    } on PostgrestException catch (e) {
      _msg(e.message);
    } catch (_) {
      _msg('No se pudo actualizar el día.');
    }
    await _cargar();
  }

  Widget _num(TextEditingController c, String etiqueta) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: etiqueta),
        ),
      );

  Future<void> _generar() async {
    final dias = TextEditingController(text: '14');
    final ini = TextEditingController(text: '9');
    final fin = TextEditingController(text: '13');
    final mins = TextEditingController(text: '30');
    final cupo = TextEditingController(text: '3');

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Generar horarios'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _num(dias, 'Días hacia adelante (desde hoy)'),
            _num(ini, 'Hora de inicio (0 a 23)'),
            _num(fin, 'Hora de fin (1 a 23)'),
            _num(mins, 'Duración de cada horario (minutos)'),
            _num(cupo, 'Lugares por horario'),
            const Text(
                'Solo se crean días de lunes a viernes. Los horarios que ya '
                'existen no se duplican.',
                style: TextStyle(fontSize: 12)),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Generar')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final hoy = DateTime.now();
      final n = await _db.rpc('generar_franjas_config', params: {
        'p_desde': _iso(DateTime(hoy.year, hoy.month, hoy.day)),
        'p_dias': int.tryParse(dias.text.trim()) ?? 0,
        'p_hora_ini': int.tryParse(ini.text.trim()) ?? 0,
        'p_hora_fin': int.tryParse(fin.text.trim()) ?? 0,
        'p_minutos': int.tryParse(mins.text.trim()) ?? 0,
        'p_cupo': int.tryParse(cupo.text.trim()) ?? 0,
      });
      _msg('Se crearon $n horarios nuevos.');
    } on PostgrestException catch (e) {
      _msg(e.message);
    } catch (_) {
      _msg('No se pudieron generar los horarios.');
    }
    await _cargar();
  }

  Widget _tarjeta(Map<String, dynamic> f) {
    final ini = DateTime.parse(f['inicio']).toLocal();
    final fin = DateTime.parse(f['fin']).toLocal();
    final activo = f['activo'] == true;
    final cupo = (f['cupo'] as num).toInt();
    final ocupadas = (f['ocupadas'] as num).toInt();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${hora(ini)} - ${hora(fin)}',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: activo ? AppColors.ink : Colors.blueGrey)),
                Text('Citas: $ocupadas de $cupo',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Menos lugares',
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => _cambiarCupo(f, -1),
          ),
          Text('$cupo', style: const TextStyle(fontWeight: FontWeight.w800)),
          IconButton(
            tooltip: 'Más lugares',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _cambiarCupo(f, 1),
          ),
          Switch(
            value: activo,
            onChanged: (v) => _actualizar(f, {'activo': v}),
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
            child: Text('Horarios de citas',
                style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          ),
          ElevatedButton.icon(
            onPressed: _generar,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generar'),
          ),
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final d in _dias)
            ChoiceChip(
              label: Text('${diaCorto(d)} ${d.day}'),
              selected: _dia == d,
              onSelected: (_) => _elegirDia(d),
            ),
          ActionChip(
            avatar: const Icon(Icons.calendar_month, size: 18),
            label: const Text('Otra fecha'),
            onPressed: _otraFecha,
          ),
        ]),
        const SizedBox(height: 20),
        Text('${fechaLarga(_dia)} ${_dia.year}',
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton(
              onPressed: () => _cambiarDia(false),
              child: const Text('Desactivar el día')),
          OutlinedButton(
              onPressed: () => _cambiarDia(true),
              child: const Text('Activar el día')),
        ]),
        const SizedBox(height: 16),
        if (_cargando)
          const Center(child: CircularProgressIndicator())
        else if (_error)
          const GlassCard(child: Text('No se pudieron cargar los horarios.'))
        else if (_franjas.isEmpty)
          const GlassCard(
              child: Text(
                  'No hay horarios para este día. Usa "Generar" para crearlos.'))
        else
          for (final f in _franjas) _tarjeta(f),
      ],
    );
  }
}