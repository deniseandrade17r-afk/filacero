import 'dart:ui';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

enum TipoAviso { exito, error, alerta, info }

TipoAviso _inferir(String mensaje) {
  final t = mensaje.toLowerCase();
  bool tiene(List<String> l) => l.any(t.contains);
  bool empieza(List<String> l) => l.any(t.startsWith);

  if (tiene(['no se pudo', 'error', 'no existe', 'ya existe', 'no puedes',
      'no puede', 'no se puede', 'no hay ', 'falló', 'inválid', 'incorrect',
      'no coinciden', 'ya tiene', 'ya está', 'ya estás', 'lleno', 'solo el',
      'solo puedes', 'falta el'])) {
    return TipoAviso.error;
  }
  if (empieza(['escribe', 'elige', 'indica', 'explica', 'agrega', 'ingresa',
          'usa ', 'confirma', 'selecciona', 'adjunta']) ||
      tiene(['mínimo', 'debes '])) {
    return TipoAviso.alerta;
  }
  if (tiene(['creada', 'creado', 'actualizad', 'guardad', 'emitid', 'enviad',
      'cancelad', 'eliminad', 'autorizad', 'agendada', 'confirmad',
      'activad', 'desactivad', 'asignó', 'se crearon', 'se activaron',
      'se desactivaron', 'retirada', 'quedaste', 'saliste', 'se creó'])) {
    return TipoAviso.exito;
  }
  return TipoAviso.info;
}

void mostrarAviso(BuildContext context, String mensaje, {TipoAviso? tipo}) {
  if (!context.mounted) return;
  final tp = tipo ?? _inferir(mensaje);
  final (icono, color) = switch (tp) {
    TipoAviso.exito => (Icons.check_circle_rounded, const Color(0xFF2E7D32)),
    TipoAviso.error => (Icons.error_rounded, AppColors.red),
    TipoAviso.alerta => (Icons.warning_amber_rounded, const Color(0xFFB7791F)),
    TipoAviso.info => (Icons.info_rounded, AppColors.navy),
  };

  final messenger = ScaffoldMessenger.of(context);
  final ancho = MediaQuery.sizeOf(context).width;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    elevation: 0,
    padding: EdgeInsets.zero,
    showCloseIcon: false,
    width: ancho > 560 ? 480 : null,
    duration: const Duration(seconds: 4),
    content: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icono, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(mensaje,
                  style: const TextStyle(
                      color: AppColors.ink, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ),
    ),
  ));
}