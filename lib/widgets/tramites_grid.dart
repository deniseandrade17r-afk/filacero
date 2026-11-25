import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'glass_card.dart';

class TramitesGrid extends StatelessWidget {
  const TramitesGrid({super.key, required this.tramites, this.onTap});
  final List<Map<String, dynamic>> tramites;
  final void Function(Map<String, dynamic> tramite)? onTap;

  static const double _gap = 16;
  static const double _padding = 20; // el de GlassCard, por cada lado
  static const double _icono = 48; // cuadro del ícono (12 + 24 + 12)
  static const double _separacion = 14;

  double _alto(BuildContext context, String texto, TextStyle estilo,
      double ancho) {
    final p = TextPainter(
      text: TextSpan(text: texto, style: estilo),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: ancho > 1 ? ancho : 1);
    return p.height;
  }

  String _modalidad(Map<String, dynamic> t) =>
      t['modalidad'] == 'presencial' ? 'Presencial (con cita)' : 'En línea';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 900 ? 3 : (c.maxWidth >= 600 ? 2 : 1);
      final ancho = (c.maxWidth - (cols - 1) * _gap) / cols;
      final anchoTexto = ancho -
          _padding * 2 -
          _icono -
          _separacion -
          (onTap != null ? 24 : 0);

      final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
      final estiloNombre =
          base.merge(const TextStyle(fontWeight: FontWeight.w700, fontSize: 16));

      var contenido = _icono;
      for (final t in tramites) {
        final h = _alto(context, t['nombre'], estiloNombre, anchoTexto) +
            2 +
            _alto(context, _modalidad(t), base, anchoTexto);
        if (h > contenido) contenido = h;
      }
      final alto = contenido + _padding * 2 + 4;

      return Wrap(spacing: _gap, runSpacing: _gap, children: [
        for (final t in tramites)
          SizedBox(
            width: ancho,
            height: alto,
            child: GlassCard(
              onTap: onTap == null ? null : () => onTap!(t),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.yellow.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    t['modalidad'] == 'presencial'
                        ? Icons.apartment_rounded
                        : Icons.laptop_mac_rounded,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(width: _separacion),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t['nombre'],
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(_modalidad(t)),
                    ],
                  ),
                ),
                if (onTap != null) const Icon(Icons.chevron_right),
              ]),
            ),
          ),
      ]);
    });
  }
}