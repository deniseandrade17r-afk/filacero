import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../utils/archivos.dart';
import '../widgets/glass_card.dart';

class DocumentosPage extends StatefulWidget {
  const DocumentosPage({super.key, required this.solicitudId});
  final dynamic solicitudId;
  @override
  State<DocumentosPage> createState() => _DocumentosPageState();
}

class _DocumentosPageState extends State<DocumentosPage> {
  final _db = Supabase.instance.client;
  Map<String, dynamic> _sol = {};
  Map<String, Map<String, dynamic>> _docs = {};
  bool _cargando = true;
  bool _error = false;
  bool _enviando = false;
  String? _subiendo;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _msg(String text) {
    if (!mounted) return;
    mostrarAviso(context, text);
  }

  Future<void> _cargar() async {
    try {
      final sol = await _db
          .from('solicitudes')
          .select(
              'id, estado, observacion, tramites(nombre, documentos, documentos_opcionales)')
          .eq('id', widget.solicitudId)
          .single();
      final docs = await _db
          .from('documentos')
          .select()
          .eq('solicitud_id', widget.solicitudId);
      if (!mounted) return;
      setState(() {
        _sol = sol;
        _docs = {for (final d in docs) d['requisito'] as String: d};
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

  Future<void> _subir(String requisito) async {
    try {
      final f = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: kExtPermitidas,
      );
      if (f == null) return; // el usuario canceló

      final Uint8List bytes = await f.readAsBytes();
      final error = validarArchivo(f.name, bytes.length);
      if (error != null) {
        _msg(error);
        return;
      }

      if (!mounted) return;
      setState(() => _subiendo = requisito);

      final uid = _db.auth.currentUser!.id;
      final ruta =
          '$uid/${widget.solicitudId}/${DateTime.now().millisecondsSinceEpoch}.${extDe(f.name)}';
      await _db.storage.from('documentos').uploadBinary(
            ruta,
            bytes,
            fileOptions: FileOptions(contentType: mimeDe(f.name)),
          );
      final anterior = _docs[requisito];
      await _db.from('documentos').upsert({
        'solicitud_id': widget.solicitudId,
        'requisito': requisito,
        'nombre_archivo': f.name,
        'ruta': ruta,
        'tamano': bytes.length,
        'mime': mimeDe(f.name),
      }, onConflict: 'solicitud_id,requisito');
      if (anterior != null) {
        try {
          await _db.storage
              .from('documentos')
              .remove([anterior['ruta'] as String]);
        } catch (_) {}
      }
      await _cargar();
    } on StorageException catch (e) {
      _msg('No se pudo subir: ${e.message}');
    } on PostgrestException catch (e) {
      _msg('No se pudo registrar el documento: ${e.message}');
    } catch (e) {
      _msg('No se pudo subir el archivo ($e).');
    } finally {
      if (mounted) setState(() => _subiendo = null);
    }
  }

  Future<void> _enviar() async {
    setState(() => _enviando = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _db.rpc('enviar_solicitud', params: {'p_id': widget.solicitudId});
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
          const SnackBar(content: Text('Solicitud enviada. Quedó como Recibida.')));
    } on PostgrestException catch (e) {
      _msg(e.message);
    } catch (_) {
      _msg('No se pudo enviar la solicitud.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Widget _fila(String requisito, bool obligatorio, bool editable) {
    final doc = _docs[requisito];
    final subido = doc != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(subido ? Icons.check_circle : Icons.radio_button_unchecked,
            color: subido ? const Color(0xFF2E7D32) : Colors.blueGrey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(requisito,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                subido
                    ? '${doc['nombre_archivo']} · ${((doc['tamano'] as int) / 1024).round()} KB'
                    : (obligatorio ? 'Pendiente' : 'Opcional'),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (editable)
          OutlinedButton(
            onPressed: _subiendo != null ? null : () => _subir(requisito),
            child: _subiendo == requisito
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(subido ? 'Reemplazar' : 'Subir'),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error) {
      return Scaffold(
        appBar: AppBar(title: const Text('Documentos')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No se pudo cargar la solicitud.'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _cargando = true;
                    _error = false;
                  });
                  _cargar();
                },
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final tr = _sol['tramites'] as Map<String, dynamic>;
    final obligatorios = ((tr['documentos'] as List?) ?? []).cast<String>();
    final opcionales =
        ((tr['documentos_opcionales'] as List?) ?? []).cast<String>();
    final editable =
        _sol['estado'] == 'borrador' || _sol['estado'] == 'requiere_correccion';
    final subidos = obligatorios.where(_docs.containsKey).length;
    final completo = subidos == obligatorios.length;

    return Scaffold(
      appBar: AppBar(title: Text(tr['nombre'])),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: GlassCard(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_sol['estado'] == 'requiere_correccion' &&
                      (_sol['observacion'] ?? '').toString().isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                          'El coordinador pidió correcciones: ${_sol['observacion']}'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                      'Sube cada documento en PDF, JPG o PNG (máximo 5 MB).'),
                  const SizedBox(height: 16),
                  const Text('Documentos obligatorios',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  for (final r in obligatorios) _fila(r, true, editable),
                  if (opcionales.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Opcionales',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                    for (final r in opcionales) _fila(r, false, editable),
                  ],
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: obligatorios.isEmpty
                        ? 1
                        : subidos / obligatorios.length,
                    color: AppColors.yellow,
                    borderRadius: BorderRadius.circular(8),
                    minHeight: 8,
                  ),
                  const SizedBox(height: 6),
                  Text(
                      '$subidos de ${obligatorios.length} documentos obligatorios'),
                  const SizedBox(height: 20),
                  if (editable)
                    FilledButton(
                      onPressed: (completo && !_enviando) ? _enviar : null,
                      child: _enviando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Enviar solicitud'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}