import 'package:material_ui/material_ui.dart';

class EditorLista extends StatefulWidget {
  const EditorLista({
    super.key,
    required this.titulo,
    required this.inicial,
    required this.onChanged,
    this.ayuda,
    this.etiquetaAgregar = 'Agregar',
  });
  final String titulo;
  final List<String> inicial;
  final ValueChanged<List<String>> onChanged;
  final String? ayuda;
  final String etiquetaAgregar;

  @override
  State<EditorLista> createState() => _EditorListaState();
}

class _EditorListaState extends State<EditorLista> {
  late final List<TextEditingController> _c =
      widget.inicial.map((e) => TextEditingController(text: e)).toList();

  void _emitir() => widget.onChanged(
      _c.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList());

  @override
  void dispose() {
    for (final c in _c) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.titulo,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        if (widget.ayuda != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(widget.ayuda!, style: const TextStyle(fontSize: 12)),
          ),
        const SizedBox(height: 8),
        for (var i = 0; i < _c.length; i++)
          Padding(
            key: ObjectKey(_c[i]),
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _c[i],
                  minLines: 1,
                  maxLines: 4,
                  onChanged: (_) => _emitir(),
                ),
              ),
              IconButton(
                tooltip: 'Quitar',
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  setState(() => _c.removeAt(i));
                  _emitir();
                },
              ),
            ]),
          ),
        TextButton.icon(
          onPressed: () => setState(() => _c.add(TextEditingController())),
          icon: const Icon(Icons.add),
          label: Text(widget.etiquetaAgregar),
        ),
      ],
    );
  }
}