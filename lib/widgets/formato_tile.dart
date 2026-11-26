import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// Formato PDF del trámite con botón "Descargar".
/// Si no hay enlace, el botón aparece apagado.
class FormatoTile extends StatelessWidget {
  const FormatoTile({super.key, required this.nombre, this.url});

  final String nombre;
  final String? url;

  bool get _hayEnlace => url != null && url!.trim().isNotEmpty;

  /// Enlaces de Google Drive (.../file/d/ID/view) -> descarga directa.
  static String enlaceDeDescarga(String u) {
    final m = RegExp(r'drive\.google\.com/file/d/([^/?#]+)').firstMatch(u);
    if (m != null) {
      return 'https://drive.google.com/uc?export=download&id=${m.group(1)}';
    }
    return u;
  }

  Future<void> _abrir(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(enlaceDeDescarga(url!.trim()));
    var ok = false;
    if (uri != null) {
      try {
        ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        ok = false;
      }
    }
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el formato.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf_outlined, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(nombre),
                if (!_hayEnlace)
                  const Text(
                    'Formato aún no disponible',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _hayEnlace ? () => _abrir(context) : null,
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Descargar'),
          ),
        ],
      ),
    );
  }
}