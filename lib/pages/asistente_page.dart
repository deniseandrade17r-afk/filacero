import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../utils/asistente.dart';
import '../widgets/glass_card.dart';
import 'solicitar_tramite_page.dart';

class _Msg {
  _Msg.asistente({this.texto, this.tramite, this.opciones, this.sugerencias})
    : delAsistente = true;
  _Msg.usuario(this.texto)
    : delAsistente = false,
      tramite = null,
      opciones = null,
      sugerencias = null;

  final bool delAsistente;
  final String? texto;
  final Map<String, dynamic>? tramite;
  final List<Map<String, dynamic>>? opciones;
  final List<String>? sugerencias;
}

class AsistentePage extends StatefulWidget {
  const AsistentePage({super.key});
  @override
  State<AsistentePage> createState() => _AsistentePageState();
}

class _AsistentePageState extends State<AsistentePage> {
  final _db = Supabase.instance.client;
  final _c = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _tramites = [];
  bool _listo = false;

  late final List<_Msg> _msgs = [
    _Msg.asistente(
      texto:
          '¡Hola! Soy el búho de FilaCero. Cuéntame qué necesitas y te '
          'oriento: qué trámite es, qué documentos reunir, quién lo atiende y '
          'cuánto tarda.',
      sugerencias: const [
        'Quiero justificar mis faltas',
        '¿Qué documentos necesito para un sobrecupo?',
        'Me quiero cambiar de carrera',
        '¿Cómo agendo una cita?',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _c.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final res = await _db.from('tramites').select().eq('activo', true);
      if (!mounted) return;
      setState(() {
        _tramites = [...res];
        _listo = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _listo = true);
    }
  }

  void _bajar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _agregar(_Msg m) {
    setState(() => _msgs.add(m));
    _bajar();
  }

  Future<void> _enviar([String? preset]) async {
    final texto = (preset ?? _c.text).trim();
    if (texto.isEmpty) return;
    _c.clear();
    _agregar(_Msg.usuario(texto));
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    _responder(texto);
  }

  void _responder(String texto) {
    if (!_listo || _tramites.isEmpty) {
      _agregar(
        _Msg.asistente(
          texto:
              'Todavía no puedo consultar el catálogo. Revisa tu conexión '
              'e intenta de nuevo en un momento.',
        ),
      );
      return;
    }
    final a = analizar(texto, _tramites);

    if (a.seguro && a.candidatos.length == 1) {
      _agregar(
        _Msg.asistente(
          texto:
              'Creo que lo que necesitas es el trámite '
              '"${a.candidatos.first['nombre']}". Esto es lo que debes saber:',
        ),
      );
      _agregar(_Msg.asistente(tramite: a.candidatos.first));
      return;
    }
    if (a.candidatos.length > 1) {
      _agregar(
        _Msg.asistente(
          texto: a.seguro
              ? 'Encontré varios trámites que podrían ser. ¿Cuál te interesa?'
              : 'No estoy seguro de cuál necesitas. ¿Alguno de estos?',
          opciones: a.candidatos,
        ),
      );
      return;
    }
    if (a.candidatos.length == 1) {
      _agregar(
        _Msg.asistente(
          texto: 'No estoy seguro, pero quizá te refieres a este trámite:',
          opciones: a.candidatos,
        ),
      );
      return;
    }
    if (a.intencion != null) {
      _agregar(_Msg.asistente(texto: _respuestaIntencion(a.intencion!)));
      return;
    }
    _agregar(
      _Msg.asistente(
        texto:
            'No logré identificar tu trámite. Puedes describirlo con otras '
            'palabras (por ejemplo: "cambiar de carrera" o "justificar faltas"), '
            'revisar el catálogo en la pestaña Trámites o consultar directamente '
            'con tu coordinación.',
        sugerencias: const [
          'Quiero justificar mis faltas',
          'Quiero estudiar dos carreras',
          '¿Cómo agendo una cita?',
        ],
      ),
    );
  }

  String _respuestaIntencion(String id) {
    switch (id) {
      case 'saludo':
        return '¡Hola! ¿En qué trámite te puedo orientar?';
      case 'gracias':
        return '¡Con gusto! Si necesitas algo más, aquí estoy.';
      case 'cita':
        return 'Para agendar una cita primero envía tu solicitud con todos tus '
            'documentos (pestaña Trámites). Cuando quede como Recibida, entra a '
            'Citas, elige el día y el horario y confirma. Solo los trámites '
            'presenciales requieren cita.';
      case 'estado':
        return 'Puedes ver en qué etapa va cada trámite en la pestaña '
            'Seguimiento. Ahí tocas una solicitud para ver su línea de tiempo.';
      case 'cancelar':
        return 'Entra a Seguimiento, abre la solicitud y usa "Cancelar trámite". '
            'Si tenías una cita, también se cancela.';
      case 'turno':
        return 'El día de tu cita verás tu lugar en la fila y el tiempo '
            'estimado en la pestaña Citas. Se actualiza solo.';
      case 'cuenta':
        return 'En la pantalla de inicio de sesión toca "¿Olvidaste tu '
            'contraseña?". Te enviamos un código a tu correo institucional.';
      default:
        return 'Puedo decirte qué trámite necesitas, qué documentos reunir, '
            'quién lo atiende y cuánto tarda. También explico cómo agendar '
            'citas, ver el estado de tu trámite y cancelar. Cuéntame qué '
            'quieres hacer.';
    }
  }

  void _verPasos(Map<String, dynamic> t) {
    final pasos = ((t['pasos'] as List?) ?? []).cast<String>();
    if (pasos.isEmpty) {
      _agregar(
        _Msg.asistente(
          texto:
              'Este trámite todavía no tiene pasos registrados. Consúltalo '
              'con tu coordinación.',
        ),
      );
      return;
    }
    final b = StringBuffer('Pasos de "${t['nombre']}":\n');
    var n = 0;
    for (final p in pasos) {
      if (p.startsWith('## ')) {
        n = 0;
        b.writeln('\n${p.substring(3)}');
      } else {
        n++;
        b.writeln('$n. $p');
      }
    }
    _agregar(_Msg.asistente(texto: b.toString().trim()));
  }

  void _solicitar(Map<String, dynamic> t) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SolicitarTramitePage(tramite: t)),
    );
  }

  Widget _avatar() => Padding(
    padding: const EdgeInsets.only(right: 8, top: 2),
    child: Image.asset(
      'assets/buho.png',
      height: 36,
      width: 36,
      errorBuilder: (_, _, _) =>
          const Icon(Icons.smart_toy_rounded, color: AppColors.navy),
    ),
  );

  Widget _caja(String texto, {bool usuario = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: usuario ? AppColors.navy : Colors.white.withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(
      texto,
      style: TextStyle(color: usuario ? Colors.white : AppColors.ink),
    ),
  );

  Widget _seccion(IconData icono, String titulo, List<String> lineas) =>
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, size: 20, color: AppColors.navy),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  for (final l in lineas) Text(l),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _tarjetaTramite(Map<String, dynamic> t) {
    List<String> lista(dynamic v) => ((v as List?) ?? []).cast<String>();
    final docs = lista(t['documentos']);
    final opc = lista(t['documentos_opcionales']);
    final obs = lista(t['observaciones']);
    final presencial = t['modalidad'] == 'presencial';
    final tiempo = (t['tiempo_estimado'] ?? '').toString();
    final atiende = (t['atiende'] ?? 'Coordinador de programa').toString();

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t['nombre'],
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          if ((t['descripcion'] ?? '').toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(t['descripcion']),
            ),
          _seccion(Icons.folder_open_rounded, 'Documentos que debes reunir', [
            ...docs,
            ...opc.map((e) => '$e (opcional)'),
          ]),
          _seccion(Icons.person_outline, 'Quién lo atiende', [atiende]),
          _seccion(Icons.schedule_rounded, 'Cuánto tarda', [
            tiempo.isEmpty ? 'Por confirmar con la coordinación' : tiempo,
          ]),
          _seccion(Icons.place_outlined, 'Modalidad', [
            presencial
                ? 'Presencial: después de enviar tus documentos agendas una cita.'
                : 'En línea: no necesitas ir en persona.',
          ]),
          if (obs.isNotEmpty)
            _seccion(Icons.info_outline, 'Importante', [obs.first]),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: () => _solicitar(t),
                child: const Text('Solicitar este trámite'),
              ),
              OutlinedButton(
                onPressed: () => _verPasos(t),
                child: const Text('Ver pasos'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _burbuja(_Msg m) {
    if (!m.delAsistente) {
      return Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _caja(m.texto!, usuario: true),
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _avatar(),
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (m.texto != null) _caja(m.texto!),
                if (m.tramite != null) _tarjetaTramite(m.tramite!),
                if (m.opciones != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final o in m.opciones!)
                          ActionChip(
                            label: Text(o['nombre']),
                            onPressed: () {
                              _agregar(_Msg.usuario(o['nombre']));
                              _agregar(_Msg.asistente(tramite: o));
                            },
                          ),
                      ],
                    ),
                  ),
                if (m.sugerencias != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in m.sugerencias!)
                          ActionChip(
                            label: Text(s),
                            onPressed: () => _enviar(s),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 34),
            const SizedBox(width: 10),
            const Text('Asistente FilaCero'),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    controller: _scroll,
                    padding: const EdgeInsets.all(20),
                    itemCount: _msgs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _burbuja(_msgs[i]),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Soy un asistente de orientación. La coordinación confirma '
                    'los requisitos de cada trámite.',
                    style: TextStyle(fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _c,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _enviar(),
                          decoration: const InputDecoration(
                            hintText: 'Escribe tu duda...',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'Enviar',
                        onPressed: _enviar,
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
