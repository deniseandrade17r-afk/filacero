import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// Fila de un formato PDF del trámite. Si tiene enlace, se puede tocar
/// para abrirlo o descargarlo; si no, se muestra apagada.
class FormatoTile extends StatelessWidget {
  const FormatoTile({super.key, required this.nombre, this.url});

  final String nombre;
  final String? url;

  bool get _hayEnlace => url != null && url!.trim().isNotEmpty;

  /// Si el enlace es de Google Drive (.../file/d/ID/view), lo convierte en
  /// enlace de descarga directa. Cualquier otro enlace se usa tal cual.
  static String enlaceDeDescarga(String u) {
    final m = RegExp(r'drive\.google\.com/file/d/([^/?#]+)').firstMatch(u);
    if (m != null) {
      return 'https://drive.google.com/uc?export=download&id=${m.group(1)}';
    }
    return u;
  }

  Future<void> _abrir(BuildContext context) async {
    final uri = Uri.tryParse(enlaceDeDescarga(url!.trim()));
    var ok = false;
    if (uri != null) {
      try {
        ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        ok = false;
      }
    }
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el formato.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      enabled: _hayEnlace,
      leading: Icon(Icons.picture_as_pdf_outlined,
          color: _hayEnlace ? color : Colors.grey),
      title: Text(nombre),
      subtitle: Text(
        _hayEnlace ? 'Toca para descargar' : 'Formato aún no disponible',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: _hayEnlace ? Icon(Icons.download_rounded, color: color) : null,
      onTap: _hayEnlace ? () => _abrir(context) : null,
    );
  }
}