import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/editor_lista.dart';
import '../widgets/glass_card.dart';

class EditarTramitePage extends StatefulWidget {
  const EditarTramitePage({super.key, this.tramite});
  final Map<String, dynamic>? tramite;
  @override
  State<EditarTramitePage> createState() => _EditarTramitePageState();
}

class _EditarTramitePageState extends State<EditarTramitePage> {
  final _db = Supabase.instance.client;
  final _form = GlobalKey<FormState>();
  late final bool _nuevo = widget.tramite == null;
  late final _nombre = TextEditingController(
    text: widget.tramite?['nombre'] ?? '',
  );
  late final _descripcion = TextEditingController(
    text: widget.tramite?['descripcion'] ?? '',
  );
  late final _minutos = TextEditingController(
    text: '${widget.tramite?['minutos_atencion'] ?? 10}',
  );
  late final _atiende = TextEditingController(
    text: widget.tramite?['atiende'] ?? 'Coordinador de programa',
  );
  late final _tiempo = TextEditingController(
    text: widget.tramite?['tiempo_estimado'] ?? '',
  );
  late List<String> _claves = _lista('palabras_clave');
  late String _modalidad = widget.tramite?['modalidad'] ?? 'presencial';
  late bool _activo = widget.tramite?['activo'] ?? true;
  late List<String> _documentos = _lista('documentos');
  late List<String> _opcionales = _lista('documentos_opcionales');
  late List<String> _pasos = _lista('pasos');
  late List<String> _obs = _lista('observaciones');
  late List<String> _formatos = _formatosIniciales();
  bool _trabajando = false;

  List<String> _lista(String k) =>
      ((widget.tramite?[k] as List?) ?? []).cast<String>().toList();

  List<String> _formatosIniciales() {
    final raw = (widget.tramite?['formatos'] as List?) ?? [];
    return raw.map((f) {
      final m = f as Map;
      return m['url'] == null
          ? '${m['nombre']}'
          : '${m['nombre']} | ${m['url']}';
    }).toList();
  }

  List<Map<String, dynamic>> _formatosParaGuardar() {
    return _formatos.map((s) {
      final p = s.split('|');
      final nombre = p.first.trim();
      final url = p.length > 1 ? p.sublist(1).join('|').trim() : '';
      return <String, dynamic>{
        'nombre': nombre,
        'url': url.isEmpty ? null : url,
      };
    }).toList();
  }

  void _msg(String t) {
    if (!mounted) return;
    mostrarAviso(context, t);
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    if (_documentos.isEmpty) {
      _msg('Agrega al menos un documento obligatorio.');
      return;
    }
    final minutos = int.tryParse(_minutos.text.trim()) ?? 0;
    final datos = <String, dynamic>{
      'nombre': _nombre.text.trim(),
      'descripcion': _descripcion.text.trim(),
      'modalidad': _modalidad,
      'minutos_atencion': minutos,
      'activo': _activo,
      'documentos': _documentos,
      'documentos_opcionales': _opcionales,
      'requisitos': [..._documentos, 'Motivo de tu solicitud'],
      'pasos': _pasos,
      'observaciones': _obs,
      'formatos': _formatosParaGuardar(),
      'atiende': _atiende.text.trim().isEmpty
          ? 'Coordinador de programa'
          : _atiende.text.trim(),
      'tiempo_estimado': _tiempo.text.trim().isEmpty
          ? null
          : _tiempo.text.trim(),
      'palabras_clave': _claves,
    };

    setState(() => _trabajando = true);
    try {
      if (_nuevo) {
        await _db.from('tramites').insert(datos);
      } else {
        await _db
            .from('tramites')
            .update(datos)
            .eq('id', widget.tramite!['id']);
      }
      if (!mounted) return;
      Navigator.pop(context);
    } on PostgrestException catch (e) {
      _msg(
        e.code == '23505' ? 'Ya existe un trámite con ese nombre.' : e.message,
      );
    } catch (_) {
      _msg('No se pudo guardar el trámite.');
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  Future<void> _eliminar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Eliminar trámite'),
        content: const Text(
          'Se eliminará este trámite del catálogo. Si ya tiene solicitudes, '
          'no se podrá eliminar y conviene desactivarlo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _trabajando = true);
    try {
      await _db.from('tramites').delete().eq('id', widget.tramite!['id']);
      if (!mounted) return;
      Navigator.pop(context);
    } on PostgrestException catch (e) {
      _msg(
        e.code == '23503'
            ? 'Este trámite ya tiene solicitudes. Desactívalo en lugar de eliminarlo.'
            : e.message,
      );
    } catch (_) {
      _msg('No se pudo eliminar el trámite.');
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  Widget _sep() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 14),
    child: Divider(),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_nuevo ? 'Nuevo trámite' : 'Editar trámite')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: GlassCard(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nombre,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                      validator: (v) => (v == null || v.trim().length < 3)
                          ? 'Escribe el nombre del trámite'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _descripcion,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Modalidad',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'presencial',
                          label: Text('Presencial'),
                        ),
                        ButtonSegment(
                          value: 'en_linea',
                          label: Text('En línea'),
                        ),
                      ],
                      selected: {_modalidad},
                      onSelectionChanged: (s) =>
                          setState(() => _modalidad = s.first),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _minutos,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText:
                            'Minutos de atención (para el tiempo estimado)',
                      ),
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        return (n == null || n < 1 || n > 240)
                            ? 'Escribe un número entre 1 y 240'
                            : null;
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Activo (visible para los alumnos)'),
                      value: _activo,
                      onChanged: (v) => setState(() => _activo = v),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _atiende,
                      decoration: const InputDecoration(
                        labelText: 'Quién lo atiende (para el asistente)',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _tiempo,
                      decoration: const InputDecoration(
                        labelText: 'Tiempo estimado (ej. 3 a 5 días hábiles)',
                      ),
                    ),
                    _sep(),
                    EditorLista(
                      titulo: 'Palabras clave del asistente',
                      ayuda: 'Frases con las que un alumno describiría este trámite, sin importar acentos. Ej.: cambiar de carrera.',
                      inicial: _claves,
                      onChanged: (l) => _claves = l,
                      etiquetaAgregar: 'Agregar palabra clave',
                    ),
                    _sep(),
                    EditorLista(
                      titulo: 'Documentos obligatorios',
                      ayuda: 'Lo que el alumno debe subir. Si cambias un nombre, las solicitudes abiertas que usaban el anterior lo perderán.',
                      inicial: _documentos,
                      onChanged: (l) => _documentos = l,
                      etiquetaAgregar: 'Agregar documento',
                    ),
                    _sep(),
                    EditorLista(
                      titulo: 'Documentos opcionales',
                      inicial: _opcionales,
                      onChanged: (l) => _opcionales = l,
                      etiquetaAgregar: 'Agregar documento opcional',
                    ),
                    _sep(),
                    EditorLista(
                      titulo: 'Pasos a seguir',
                      ayuda: 'Una línea que empiece con ## es un subtítulo y reinicia la numeración.',
                      inicial: _pasos,
                      onChanged: (l) => _pasos = l,
                      etiquetaAgregar: 'Agregar paso',
                    ),
                    _sep(),
                    EditorLista(
                      titulo: 'Observaciones',
                      inicial: _obs,
                      onChanged: (l) => _obs = l,
                      etiquetaAgregar: 'Agregar observación',
                    ),
                    _sep(),
                    EditorLista(
                      titulo: 'Formatos',
                      ayuda: 'Escribe: Nombre del formato | https://enlace (el enlace es opcional).',
                      inicial: _formatos,
                      onChanged: (l) => _formatos = l,
                      etiquetaAgregar: 'Agregar formato',
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _trabajando ? null : _guardar,
                      child: const Text('Guardar'),
                    ),
                    if (!_nuevo) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _trabajando ? null : _eliminar,
                        child: const Text('Eliminar trámite'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
